package dev.lolren.waydroidcameraprobe;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.MeteringRectangle;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.CamcorderProfile;
import android.media.EncoderProfiles;
import android.media.Image;
import android.media.ImageReader;
import android.media.MediaMetadataRetriever;
import android.media.MediaRecorder;
import android.os.Bundle;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.SystemClock;
import android.util.Log;
import android.util.Range;
import android.util.Rational;
import android.util.Size;
import android.view.PixelCopy;
import android.view.Surface;
import android.view.TextureView;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.atomic.AtomicBoolean;

public final class CameraProbeActivity extends Activity {
    private static final String TAG = "WaydroidCameraProbe";
    private static final String PROFILE_FULL = "full";
    private static final String PROFILE_PREVIEW = "preview";
    private static final String PROFILE_PREVIEW_YUV = "preview-yuv";
    private static final String PROFILE_SURFACE = "surface";
    private static final String PROFILE_SURFACE_YUV = "surface-yuv";
    private static final String PROFILE_RECORD = "record";
    private static final String PROFILE_RECORD_YUV_720P = "record-yuv-720p";
    private static final String PROFILE_ENCODE_720P = "encode-720p";
    private static final String PROFILE_TAP_FOCUS = "tap-focus";
    private static final String PROFILE_MANUAL_FOCUS = "manual-focus";
    private static final int SETTLE_FRAMES = 6;
    private static final int MANUAL_FOCUS_SETTLE_FRAMES = 12;
    private static final int EV_SETTLE_FRAMES = 60;
    private static final int EV_SAMPLE_FRAMES = 8;
    private static final int MIN_WARMUP_FRAMES = 30;
    private static final int MAX_WARMUP_FRAMES = 360;
    private static final int SENSOR_STABLE_FRAMES = 20;
    private static final int MIN_PRIVATE_TIMING_FRAMES = 30;
    private static final long CAMERA_TIMEOUT_MS = 120000;
    private static final long FULL_CAMERA_TIMEOUT_MS = 360000;
    private static final long ENCODE_DURATION_MS = 10000;

    private final List<String> results = new ArrayList<>();
    private final Set<Integer> afStates = new TreeSet<>();
    private String profile = PROFILE_FULL;
    private HandlerThread cameraThread;
    private Handler handler;
    private CameraManager manager;
    private String[] cameraIds = new String[0];
    private int cameraIndex;
    private int generation;
    private boolean enumerationComplete;
    private boolean cameraSequenceStarted;
    private boolean surfaceReady;
    private volatile int surfaceToken;
    private int frameCount;
    private int yuvFrames;
    private int privateFrames;
    private int privateTimedFrames;
    private long privateFirstTimestamp;
    private long privateLastTimestamp;
    private int captureTimedFrames;
    private long captureFirstTimestamp;
    private long captureLastTimestamp;
    private Size privateStreamSize;
    private int selectedAfMode;
    private boolean manualFocusSupported;
    private float manualFocusDistanceMax;
    private int manualFocusStage;
    private int manualFocusStageFrames;
    private float manualFocusFirstDistance;
    private float manualFocusSecondDistance;
    private boolean manualFocusFirstObserved;
    private boolean manualFocusSecondObserved;
    private boolean manualFocusComplete;
    private int currentExposureCompensation;
    private int[] exposureRequests;
    private double[] exposureMeans;
    private int exposureStage;
    private int exposureStageFrames;
    private int exposureSampleCount;
    private double exposureSampleSum;
    private boolean exposureWarm;
    private int warmupFrames;
    private int stableSensorFrames;
    private long warmupExposureTime;
    private int warmupSensitivity;
    private long warmupFrameDuration;
    private long latestSensorExposureTime;
    private int latestSensorSensitivity;
    private long latestSensorFrameDuration;
    private boolean cameraCompleting;
    private boolean exposureComplete;
    private boolean yuvAccepted;
    private boolean jpegRequested;
    private boolean jpegAccepted;
    private boolean privateAccepted;
    private boolean surfacePixelSamplePending;
    private boolean recorderStarted;
    private boolean recorderAccepted;
    private String yuvResult;
    private String jpegResult;
    private String surfacePixelResult;
    private String recorderResult;
    private String exposureResult;
    private Rational exposureStep;
    private Range<Integer> selectedFpsRange;
    private Range<Long> sensorExposureRange;
    private Range<Integer> sensorSensitivityRange;
    private long[] sensorExposureTimes;
    private int[] sensorSensitivities;
    private long[] sensorFrameDurations;
    private MeteringRectangle[] focusRegions;
    private final Set<Integer> exposureMetadata = new TreeSet<>();
    private CameraDevice camera;
    private CameraCaptureSession session;
    private CaptureRequest.Builder previewRequest;
    private ImageReader yuvReader;
    private ImageReader jpegReader;
    private ImageReader privateReader;
    private TextureView textureView;
    private SurfaceTexture previewTexture;
    private Surface previewSurface;
    private MediaRecorder mediaRecorder;
    private Surface recorderSurface;
    private File encodedFile;
    private Runnable recorderStop;
    private CameraDevice closingCamera;
    private Runnable cameraCloseContinuation;
    private Runnable cameraCloseTimeout;
    private int cameraCloseGeneration;
    private final AtomicBoolean surfaceSamplePending = new AtomicBoolean();
    private Runnable timeout;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        profile = normalizeProfile(getIntent().getStringExtra("profile"));
        Log.i(TAG, "PROBE_PROFILE " + profile);

        if (needsSurface()) {
            textureView = new TextureView(this);
            textureView.setSurfaceTextureListener(new TextureView.SurfaceTextureListener() {
                @Override
                public void onSurfaceTextureAvailable(SurfaceTexture surface, int width,
                        int height) {
                    previewTexture = surface;
                    previewSurface = new Surface(surface);
                    surfaceReady = true;
                    if (handler != null)
                        handler.post(CameraProbeActivity.this::maybeStartCameras);
                }

                @Override
                public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width,
                        int height) {
                }

                @Override
                public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
                    surfaceReady = false;
                    surfaceSamplePending.set(false);
                    previewTexture = null;
                    if (previewSurface != null) {
                        previewSurface.release();
                        previewSurface = null;
                    }
                    return true;
                }

                @Override
                public void onSurfaceTextureUpdated(SurfaceTexture surface) {
                    final int token = surfaceToken;
                    final long timestamp = System.nanoTime();
                    if (handler != null && token != 0
                            && surfaceSamplePending.compareAndSet(false, true))
                        handler.post(() -> onSurfaceFrame(token, timestamp));
                }
            });
            setContentView(textureView);
        }

        cameraThread = new HandlerThread("waydroid-camera-probe");
        cameraThread.start();
        handler = new Handler(cameraThread.getLooper());
        manager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);

        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            finishProbe("camera permission was not granted");
            return;
        }
        if (needsEncodedVideo()
                && checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                        != PackageManager.PERMISSION_GRANTED) {
            finishProbe("record-audio permission was not granted");
            return;
        }

        handler.post(() -> {
            try {
                String[] availableCameraIds = manager.getCameraIdList();
                String requestedCameraId = getIntent().getStringExtra("camera-id");
                if (requestedCameraId != null && !requestedCameraId.isEmpty()) {
                    if (!Arrays.asList(availableCameraIds).contains(requestedCameraId)) {
                        finishProbe("requested camera ID is unavailable: "
                                + requestedCameraId);
                        return;
                    }
                    cameraIds = new String[]{requestedCameraId};
                } else {
                    cameraIds = availableCameraIds;
                }
                enumerationComplete = true;
                Log.i(TAG, "PROBE_START cameras=" + cameraIds.length
                        + " available=" + availableCameraIds.length);
                logEncoderProfiles(cameraIds);
                maybeStartCameras();
            } catch (Throwable e) {
                finishProbe("enumeration failed: " + compactError(e));
            }
        });
    }

    /**
     * Record the legacy and API-31+ recording-profile view for every camera.
     * CameraX uses EncoderProfiles to decide whether to expose video mode, so
     * this makes a missing or rejected media_profiles declaration visible in a
     * reproducible probe run instead of only in the camera application's UI.
     */
    private void logEncoderProfiles(String[] ids) {
        int[] qualities = new int[]{
                CamcorderProfile.QUALITY_2160P,
                CamcorderProfile.QUALITY_1080P,
                CamcorderProfile.QUALITY_720P,
                CamcorderProfile.QUALITY_480P,
                CamcorderProfile.QUALITY_HIGH,
                CamcorderProfile.QUALITY_LOW,
                CamcorderProfile.QUALITY_QVGA
        };
        for (String id : ids) {
            int cameraId;
            try {
                cameraId = Integer.parseInt(id);
            } catch (NumberFormatException e) {
                Log.w(TAG, "MEDIA_PROFILE camera=" + id + " skipped=non-numeric-id");
                continue;
            }
            for (int quality : qualities) {
                boolean has = false;
                boolean all = false;
                int videoProfiles = -1;
                try {
                    has = CamcorderProfile.hasProfile(cameraId, quality);
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        EncoderProfiles profiles = CamcorderProfile.getAll(id, quality);
                        all = profiles != null;
                        if (profiles != null && profiles.getVideoProfiles() != null)
                            videoProfiles = profiles.getVideoProfiles().size();
                    }
                } catch (Throwable e) {
                    Log.w(TAG, "MEDIA_PROFILE camera=" + id + " quality=" + quality
                            + " error=" + compactError(e));
                }
                Log.i(TAG, "MEDIA_PROFILE camera=" + id + " quality=" + quality
                        + " has=" + has + " all=" + all
                        + " videoProfiles=" + videoProfiles);
            }
        }
    }

    private void maybeStartCameras() {
        if (!enumerationComplete || cameraSequenceStarted
                || (needsSurface() && !surfaceReady))
            return;
        cameraSequenceStarted = true;
        startNextCamera();
    }

    private void startNextCamera() {
        closeCamera(this::openNextCamera);
    }

    private void openNextCamera() {
        if (cameraIndex >= cameraIds.length) {
            finishProbe(null);
            return;
        }

        final int token = ++generation;
        final String id = cameraIds[cameraIndex];
        surfaceToken = token;
        frameCount = 0;
        yuvFrames = 0;
        privateFrames = 0;
        privateTimedFrames = 0;
        privateFirstTimestamp = 0;
        privateLastTimestamp = 0;
        captureTimedFrames = 0;
        captureFirstTimestamp = 0;
        captureLastTimestamp = 0;
        privateStreamSize = null;
        cameraCompleting = false;
        yuvAccepted = false;
        jpegRequested = false;
        jpegAccepted = false;
        privateAccepted = false;
        yuvResult = null;
        jpegResult = null;
        surfacePixelSamplePending = false;
        surfacePixelResult = null;
        recorderStarted = false;
        recorderAccepted = false;
        recorderResult = null;
        exposureResult = null;
        exposureStep = null;
        selectedFpsRange = null;
        sensorExposureRange = null;
        sensorSensitivityRange = null;
        sensorExposureTimes = null;
        sensorSensitivities = null;
        sensorFrameDurations = null;
        exposureRequests = null;
        exposureMeans = null;
        exposureStage = 0;
        exposureStageFrames = 0;
        exposureSampleCount = 0;
        exposureSampleSum = 0.0;
        exposureWarm = false;
        warmupFrames = 0;
        stableSensorFrames = 0;
        warmupExposureTime = 0;
        warmupSensitivity = 0;
        warmupFrameDuration = 0;
        latestSensorExposureTime = 0;
        latestSensorSensitivity = 0;
        latestSensorFrameDuration = 0;
        currentExposureCompensation = 0;
        exposureComplete = false;
        focusRegions = null;
        manualFocusSupported = false;
        manualFocusDistanceMax = 0.0f;
        manualFocusStage = 0;
        manualFocusStageFrames = 0;
        manualFocusFirstDistance = Float.NaN;
        manualFocusSecondDistance = Float.NaN;
        manualFocusFirstObserved = false;
        manualFocusSecondObserved = false;
        manualFocusComplete = false;
        afStates.clear();
        exposureMetadata.clear();

        /*
         * The OnePlus 6T auxiliary rear stream reproducibly drives the
         * current Venus/V4L2 Codec2 stack into a firmware-recovery IRQ storm
         * after encoder stop. Refuse that one destructive combination before
         * allocating a camera or codec; YUV/JPEG/preview profiles remain safe.
         */
        if (needsEncodedVideo() && "1".equals(id)) {
            failCamera(token, id,
                    "auxiliary hardware encoding is disabled after a Venus teardown fault");
            return;
        }

        try {
            CameraCharacteristics characteristics = manager.getCameraCharacteristics(id);
            StreamConfigurationMap map = characteristics.get(
                    CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            if (map == null) {
                failCamera(token, id, "missing stream configuration map");
                return;
            }

            Size size = null;
            if (needsYuv()) {
                Size[] yuvSizes = map.getOutputSizes(ImageFormat.YUV_420_888);
                size = needsRecordingYuv720p()
                        ? chooseRecordingYuvSize(yuvSizes) : chooseProbeSize(yuvSizes);
                if (size == null) {
                    failCamera(token, id, "no YUV_420_888 output size");
                    return;
                }
            }
            Size[] privateSizes = map.getOutputSizes(ImageFormat.PRIVATE);
            if (privateSizes == null || privateSizes.length == 0)
                privateSizes = map.getOutputSizes(SurfaceTexture.class);
            /*
             * Android 13 may retain format 34 in the static metadata while
             * both public PRIVATE queries return null.  The libcamera HAL
             * advertises the same ordinary dimensions for YUV and PRIVATE;
             * using that list still lets camera session configuration be the
             * authoritative support check.
             */
            if (privateSizes == null || privateSizes.length == 0)
                privateSizes = map.getOutputSizes(ImageFormat.YUV_420_888);
            CamcorderProfile recordingProfile = null;
            Size privateSize;
            if (needsEncodedVideo()) {
                int numericId;
                try {
                    numericId = Integer.parseInt(id);
                } catch (NumberFormatException error) {
                    failCamera(token, id, "encoded recording requires a numeric camera ID");
                    return;
                }
                if (!CamcorderProfile.hasProfile(numericId, CamcorderProfile.QUALITY_720P)) {
                    failCamera(token, id, "720p CamcorderProfile is unavailable");
                    return;
                }
                recordingProfile = CamcorderProfile.get(
                        numericId, CamcorderProfile.QUALITY_720P);
                privateSize = new Size(recordingProfile.videoFrameWidth,
                        recordingProfile.videoFrameHeight);
                if (!containsSize(privateSizes, privateSize)) {
                    failCamera(token, id, "720p encoder size is unavailable: " + privateSize);
                    return;
                }
            } else {
                privateSize = choosePrivateProbeSize(privateSizes, size);
            }
            if (privateSize == null) {
                failCamera(token, id, "no PRIVATE output size");
                return;
            }
            privateStreamSize = privateSize;
            if (needsSurface()) {
                if (!surfaceReady || previewTexture == null || previewSurface == null) {
                    failCamera(token, id, "preview surface is unavailable");
                    return;
                }
                previewTexture.setDefaultBufferSize(
                        privateSize.getWidth(), privateSize.getHeight());
            }
            if (needsJpeg() && !containsSize(map.getOutputSizes(ImageFormat.JPEG), size)) {
                failCamera(token, id, "matching JPEG output size is unavailable");
                return;
            }

            int[] modes = characteristics.get(
                    CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
            selectedAfMode = chooseAutofocusMode(modes, needsRecordTemplate());
            if (PROFILE_TAP_FOCUS.equals(profile)
                    && contains(modes, CaptureRequest.CONTROL_AF_MODE_AUTO))
                selectedAfMode = CaptureRequest.CONTROL_AF_MODE_AUTO;
            Float minimumFocusDistance = characteristics.get(
                    CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE);
            manualFocusDistanceMax = minimumFocusDistance == null
                    ? 0.0f : minimumFocusDistance;
            manualFocusSupported = needsManualFocus()
                    && manualFocusDistanceMax > 0.0f
                    && contains(modes, CaptureRequest.CONTROL_AF_MODE_OFF);
            Integer maxAfRegions = characteristics.get(
                    CameraCharacteristics.CONTROL_MAX_REGIONS_AF);
            Integer lensFacing = characteristics.get(
                    CameraCharacteristics.LENS_FACING);
            Integer sensorOrientation = characteristics.get(
                    CameraCharacteristics.SENSOR_ORIENTATION);
            Range<Integer> exposureRange = characteristics.get(
                    CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE);
            exposureStep = characteristics.get(
                    CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP);
            if (needsFullValidation() && (exposureRange == null || exposureStep == null
                    || exposureRange.getLower() >= 0
                    || exposureRange.getUpper() <= 0
                    || exposureStep.doubleValue() <= 0.0)) {
                failCamera(token, id, "exposure compensation unavailable: range="
                        + exposureRange + " step=" + exposureStep);
                return;
            }
            if (needsFullValidation()) {
                exposureRequests = new int[]{0, exposureRange.getLower(), 0,
                        exposureRange.getUpper(), 0};
                exposureMeans = new double[exposureRequests.length];
                sensorExposureTimes = new long[exposureRequests.length];
                sensorSensitivities = new int[exposureRequests.length];
                sensorFrameDurations = new long[exposureRequests.length];
            } else {
                exposureComplete = true;
                exposureWarm = true;
            }
            Range<Integer>[] fpsRanges = characteristics.get(
                    CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES);
            /*
             * Let MediaRecorder and camera timestamps negotiate the real
             * cadence for an encoded run. Forcing a nominal profile rate on
             * the capture request is known to make MediaRecorder.stop() fail
             * on otherwise valid Camera2 sessions, and the auxiliary sensor
             * advertises 15 FPS in its profile but no fixed [15, 15] AE range.
             */
            selectedFpsRange = needsEncodedVideo() ? null
                    : needsRecordTemplate() ? chooseRecordFpsRange(fpsRanges)
                    : choosePreviewFpsRange(fpsRanges);
            sensorExposureRange = characteristics.get(
                    CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE);
            sensorSensitivityRange = characteristics.get(
                    CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE);
            Rect active = characteristics.get(
                    CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE);
            if (active != null && maxAfRegions != null && maxAfRegions > 0 &&
                    selectedAfMode != CaptureRequest.CONTROL_AF_MODE_OFF) {
                int insetX = active.width() / 4;
                int insetY = active.height() / 4;
                focusRegions = new MeteringRectangle[]{new MeteringRectangle(
                        active.left + insetX, active.top + insetY,
                        Math.max(1, active.width() - insetX * 2),
                        Math.max(1, active.height() - insetY * 2), 1000)};
            }
            Log.i(TAG, "CAPABILITY id=" + id + " afModes=" + Arrays.toString(modes)
                    + " maxAfRegions=" + maxAfRegions + " lensFacing=" + lensFacing
                    + " sensorOrientation=" + sensorOrientation
                    + " manualFocusSupported=" + manualFocusSupported
                    + " manualFocusDistanceMax=" + manualFocusDistanceMax
                    + " probeSize=" + size + " aeRange=" + exposureRange
                    + " aeStep=" + exposureStep
                    + " privateSize=" + privateSize
                    + " fpsRanges=" + Arrays.toString(fpsRanges)
                    + " selectedFps=" + selectedFpsRange
                    + " sensorExposureRangeNs=" + sensorExposureRange
                    + " sensorSensitivityRange=" + sensorSensitivityRange);

            if (needsYuv()) {
                yuvReader = ImageReader.newInstance(
                        size.getWidth(), size.getHeight(), ImageFormat.YUV_420_888, 3);
                yuvReader.setOnImageAvailableListener(r -> onYuvImage(token, id, r), handler);
            }
            if (needsJpeg()) {
                jpegReader = ImageReader.newInstance(
                        size.getWidth(), size.getHeight(), ImageFormat.JPEG, 2);
                jpegReader.setOnImageAvailableListener(r -> onJpegImage(token, id, r), handler);
            }
            if (!needsSurface()) {
                privateReader = ImageReader.newInstance(
                        privateSize.getWidth(), privateSize.getHeight(),
                        ImageFormat.PRIVATE, 3);
                privateReader.setOnImageAvailableListener(r -> onPrivateImage(token, r), handler);
            }
            if (needsEncodedVideo())
                prepareMediaRecorder(id, recordingProfile);

            timeout = () -> failCamera(token, id,
                    "timed out: profile=" + profile
                            + " yuv=" + yuvAccepted + "/" + yuvFrames
                            + " jpeg=" + jpegAccepted + "/" + jpegRequested
                            + " private=" + privateAccepted + "/" + privateFrames
                            + " recorder=" + recorderAccepted + "/" + recorderStarted
                            + " afStates=" + afStates
                            + " exposureWarm=" + exposureWarm
                            + " warmupFrames=" + warmupFrames
                            + " stableSensorFrames=" + stableSensorFrames
                            + " exposureStage=" + exposureStage
                            + " exposureStageFrames=" + exposureStageFrames
                            + " latestSensor=[" + latestSensorExposureTime + ","
                            + latestSensorSensitivity + ","
                            + latestSensorFrameDuration + "]");
            handler.postDelayed(timeout, cameraTimeoutMs());
            manager.openCamera(id, cameraStateCallback(token, id), handler);
        } catch (Throwable e) {
            failCamera(token, id, "open setup failed: " + compactError(e));
        }
    }

    private CameraDevice.StateCallback cameraStateCallback(int token, String id) {
        return new CameraDevice.StateCallback() {
            @Override
            public void onOpened(CameraDevice opened) {
                if (!isCurrent(token)) {
                    opened.close();
                    return;
                }
                camera = opened;
                try {
                    List<android.view.Surface> surfaces = new ArrayList<>();
                    surfaces.add(needsSurface() ? previewSurface : privateReader.getSurface());
                    if (yuvReader != null)
                        surfaces.add(yuvReader.getSurface());
                    if (jpegReader != null)
                        surfaces.add(jpegReader.getSurface());
                    if (recorderSurface != null)
                        surfaces.add(recorderSurface);
                    opened.createCaptureSession(surfaces,
                            sessionStateCallback(token, id, opened), handler);
                } catch (Exception e) {
                    failCamera(token, id,
                            "session creation failed: " + compactError(e));
                }
            }

            @Override
            public void onDisconnected(CameraDevice disconnected) {
                failCamera(token, id, "camera disconnected");
            }

            @Override
            public void onError(CameraDevice failed, int error) {
                failCamera(token, id, "device error " + error);
            }

            @Override
            public void onClosed(CameraDevice closed) {
                finishCameraClose(closed);
            }
        };
    }

    private CameraCaptureSession.StateCallback sessionStateCallback(
            int token, String id, CameraDevice opened) {
        return new CameraCaptureSession.StateCallback() {
            @Override
            public void onConfigured(CameraCaptureSession configured) {
                if (!isCurrent(token)) {
                    configured.close();
                    return;
                }
                session = configured;
                try {
                    previewRequest = opened.createCaptureRequest(captureTemplate());
                    previewRequest.addTarget(needsSurface()
                            ? previewSurface : privateReader.getSurface());
                    if (yuvReader != null)
                        previewRequest.addTarget(yuvReader.getSurface());
                    if (recorderSurface != null)
                        previewRequest.addTarget(recorderSurface);
                    if (needsManualFocus() && manualFocusSupported)
                        applyManualControls(previewRequest, 0.0f);
                    else
                        applyAutomaticControls(previewRequest, false);
                    configured.setRepeatingRequest(previewRequest.build(),
                            captureCallback(token), handler);

                    if (selectedAfMode == CaptureRequest.CONTROL_AF_MODE_AUTO) {
                        CaptureRequest.Builder trigger = opened.createCaptureRequest(
                                captureTemplate());
                        trigger.addTarget(needsSurface()
                                ? previewSurface : privateReader.getSurface());
                        if (yuvReader != null)
                            trigger.addTarget(yuvReader.getSurface());
                        if (recorderSurface != null)
                            trigger.addTarget(recorderSurface);
                        applyAutomaticControls(trigger, true);
                        configured.capture(trigger.build(), captureCallback(token), handler);
                    }
                    if (needsEncodedVideo()) {
                        mediaRecorder.start();
                        recorderStarted = true;
                        final long startedAt = SystemClock.elapsedRealtime();
                        recorderStop = () -> stopEncodedRecording(token, id, startedAt);
                        handler.postDelayed(recorderStop, ENCODE_DURATION_MS);
                    }
                } catch (Exception e) {
                    failCamera(token, id,
                            "capture start failed: " + compactError(e));
                }
            }

            @Override
            public void onConfigureFailed(CameraCaptureSession failed) {
                failCamera(token, id, "capture session configuration failed");
            }
        };
    }

    private CameraCaptureSession.CaptureCallback captureCallback(int token) {
        return new CameraCaptureSession.CaptureCallback() {
            @Override
            public void onCaptureCompleted(CameraCaptureSession captureSession,
                    CaptureRequest request, TotalCaptureResult result) {
                if (!isCurrent(token))
                    return;
                Integer state = result.get(CaptureResult.CONTROL_AF_STATE);
                if (state != null) {
                    afStates.add(state);
                    maybeCompleteCamera(token);
                }
                if (needsManualFocus() && manualFocusSupported
                        && !manualFocusComplete) {
                    Float focusDistance = result.get(
                            CaptureResult.LENS_FOCUS_DISTANCE);
                    Float requestedDistance = request.get(
                            CaptureRequest.LENS_FOCUS_DISTANCE);
                    if (focusDistance != null && requestedDistance != null) {
                        if (requestedDistance <= manualFocusDistanceMax / 2.0f) {
                            /* Keep the settled result from the first
                             * request. A few old requests can be delivered
                             * after the second repeating request is queued. */
                            if (!manualFocusFirstObserved) {
                                manualFocusFirstDistance = focusDistance;
                                manualFocusFirstObserved = true;
                            }
                        } else {
                            if (!manualFocusSecondObserved) {
                                manualFocusSecondDistance = focusDistance;
                                manualFocusSecondObserved = true;
                            }
                        }
                    }

                    manualFocusStageFrames++;
                    if (manualFocusStage == 0
                            && manualFocusStageFrames >= MANUAL_FOCUS_SETTLE_FRAMES) {
                        manualFocusStage = 1;
                        manualFocusStageFrames = 0;
                        requestManualFocus(token, 1.0f * manualFocusDistanceMax);
                    } else if (manualFocusStage == 1
                            && manualFocusStageFrames >= MANUAL_FOCUS_SETTLE_FRAMES) {
                        manualFocusStage = 2;
                        manualFocusComplete = true;
                        Log.i(TAG, String.format(Locale.US,
                                "MANUAL_FOCUS requested=[0.000,%.3f] result=[%.3f,%.3f]",
                                manualFocusDistanceMax, manualFocusFirstDistance,
                                manualFocusSecondDistance));
                        maybeCompleteCamera(token);
                    }
                }
                Integer compensation = result.get(
                        CaptureResult.CONTROL_AE_EXPOSURE_COMPENSATION);
                if (compensation != null)
                    exposureMetadata.add(compensation);
                Long exposureTime = result.get(CaptureResult.SENSOR_EXPOSURE_TIME);
                Integer sensitivity = result.get(CaptureResult.SENSOR_SENSITIVITY);
                Long frameDuration = result.get(CaptureResult.SENSOR_FRAME_DURATION);
                Long sensorTimestamp = result.get(CaptureResult.SENSOR_TIMESTAMP);
                if (sensorTimestamp != null && sensorTimestamp > 0) {
                    if (captureFirstTimestamp == 0)
                        captureFirstTimestamp = sensorTimestamp;
                    if (captureLastTimestamp > 0
                            && sensorTimestamp > captureLastTimestamp)
                        captureTimedFrames++;
                    captureLastTimestamp = sensorTimestamp;
                }
                if (exposureTime != null)
                    latestSensorExposureTime = exposureTime;
                if (sensitivity != null)
                    latestSensorSensitivity = sensitivity;
                if (frameDuration != null)
                    latestSensorFrameDuration = frameDuration;
                if (!exposureWarm && exposureTime != null && sensitivity != null
                        && frameDuration != null) {
                    if (warmupExposureTime > 0
                            && closeEnough(exposureTime, warmupExposureTime)
                            && closeEnough(sensitivity, warmupSensitivity)
                            && closeEnough(frameDuration, warmupFrameDuration))
                        stableSensorFrames++;
                    else
                        stableSensorFrames = 0;
                    warmupExposureTime = exposureTime;
                    warmupSensitivity = sensitivity;
                    warmupFrameDuration = frameDuration;
                }
                if (exposureWarm && exposureRequests != null
                        && exposureStage < exposureRequests.length) {
                    if (exposureTime != null)
                        sensorExposureTimes[exposureStage] = exposureTime;
                    if (sensitivity != null)
                        sensorSensitivities[exposureStage] = sensitivity;
                    if (frameDuration != null)
                        sensorFrameDurations[exposureStage] = frameDuration;
                }
            }
        };
    }

    private void applyAutomaticControls(CaptureRequest.Builder request, boolean trigger) {
        request.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
        request.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
        request.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                currentExposureCompensation);
        if (selectedFpsRange != null)
            request.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                    selectedFpsRange);
        request.set(CaptureRequest.CONTROL_AF_MODE, selectedAfMode);
        if (focusRegions != null)
            request.set(CaptureRequest.CONTROL_AF_REGIONS, focusRegions);
        request.set(CaptureRequest.CONTROL_AF_TRIGGER,
                trigger ? CaptureRequest.CONTROL_AF_TRIGGER_START
                        : CaptureRequest.CONTROL_AF_TRIGGER_IDLE);
    }

    private void applyManualControls(CaptureRequest.Builder request, float distance) {
        request.set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO);
        request.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON);
        request.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION,
                currentExposureCompensation);
        if (selectedFpsRange != null)
            request.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                    selectedFpsRange);
        request.set(CaptureRequest.CONTROL_AF_MODE,
                CaptureRequest.CONTROL_AF_MODE_OFF);
        request.set(CaptureRequest.LENS_FOCUS_DISTANCE,
                Math.max(0.0f, Math.min(manualFocusDistanceMax, distance)));
    }

    private void requestManualFocus(int token, float distance) {
        if (!isCurrent(token) || camera == null || session == null)
            return;
        try {
            CaptureRequest.Builder request = camera.createCaptureRequest(
                    captureTemplate());
            request.addTarget(privateReader.getSurface());
            applyManualControls(request, distance);
            session.setRepeatingRequest(request.build(), captureCallback(token), handler);
        } catch (Exception error) {
            failCamera(token, cameraIds[cameraIndex],
                    "manual focus update failed: " + compactError(error));
        }
    }

    private void prepareMediaRecorder(String id, CamcorderProfile recordingProfile)
            throws Exception {
        encodedFile = new File(getFilesDir(), "encoded-camera-" + id + ".mp4");
        if (encodedFile.exists() && !encodedFile.delete())
            throw new IllegalStateException("could not remove previous encoded output");

        mediaRecorder = new MediaRecorder();
        mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
        mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE);
        mediaRecorder.setProfile(recordingProfile);
        mediaRecorder.setOutputFile(encodedFile.getAbsolutePath());
        mediaRecorder.prepare();
        recorderSurface = mediaRecorder.getSurface();
    }

    private void stopEncodedRecording(int token, String id, long startedAt) {
        recorderStop = null;
        if (!isCurrent(token) || !recorderStarted || mediaRecorder == null)
            return;

        try {
            /*
             * Match Android's Camera2 recording lifecycle: stop the source
             * and close its capture session before asking MediaRecorder to
             * drain and stop the encoder. This prevents new camera buffers
             * racing Codec2 STREAMOFF and DMA-BUF teardown.
             */
            if (session != null) {
                session.stopRepeating();
                session.close();
                session = null;
            }
            mediaRecorder.stop();
            recorderStarted = false;
            recorderResult = analyzeEncodedVideo(encodedFile,
                    SystemClock.elapsedRealtime() - startedAt);
            recorderAccepted = recorderResult.contains("encodedValid=true");
            if (!recorderAccepted) {
                failCamera(token, id, "encoded recording was invalid: " + recorderResult);
                return;
            }
            maybeCompleteCamera(token);
        } catch (Throwable error) {
            recorderStarted = false;
            failCamera(token, id, "encoded recording stop failed: " + compactError(error));
        }
    }

    private static String analyzeEncodedVideo(File file, long elapsedMs) throws Exception {
        long bytes = file == null || !file.isFile() ? 0 : file.length();
        MediaMetadataRetriever metadata = new MediaMetadataRetriever();
        String durationText = null;
        String widthText = null;
        String heightText = null;
        String hasVideo = null;
        String hasAudio = null;
        String frameCount = null;
        String captureFps = null;
        try {
            metadata.setDataSource(file.getAbsolutePath());
            durationText = metadata.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION);
            widthText = metadata.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH);
            heightText = metadata.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT);
            hasVideo = metadata.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO);
            hasAudio = metadata.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                frameCount = metadata.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                captureFps = metadata.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE);
        } finally {
            metadata.release();
        }

        long durationMs = parseLong(durationText);
        int width = (int) parseLong(widthText);
        int height = (int) parseLong(heightText);
        boolean valid = bytes > 4096 && durationMs >= ENCODE_DURATION_MS / 2
                && width > 0 && height > 0
                && "yes".equalsIgnoreCase(hasVideo)
                && "yes".equalsIgnoreCase(hasAudio);
        return String.format(Locale.US,
                "encodedValid=%s encodedFile=%s encodedBytes=%d "
                        + "encodedDurationMs=%d encodedElapsedMs=%d encodedSize=%dx%d "
                        + "encodedHasVideo=%s encodedHasAudio=%s "
                        + "encodedFrames=%s encodedCaptureFps=%s",
                valid, file.getName(), bytes, durationMs, elapsedMs, width, height,
                hasVideo, hasAudio, frameCount, captureFps);
    }

    private static long parseLong(String value) {
        if (value == null)
            return 0;
        try {
            return Long.parseLong(value);
        } catch (NumberFormatException error) {
            return 0;
        }
    }

    private void onPrivateImage(int token, ImageReader source) {
        Image image = source.acquireLatestImage();
        if (image == null)
            return;
        try {
            if (!isCurrent(token))
                return;
            privateFrames++;
            long timestamp = image.getTimestamp();
            if (timestamp > 0) {
                if (privateFirstTimestamp == 0)
                    privateFirstTimestamp = timestamp;
                if (privateLastTimestamp > 0 && timestamp > privateLastTimestamp)
                    privateTimedFrames++;
                privateLastTimestamp = timestamp;
            }
            privateAccepted = true;
            maybeCompleteCamera(token);
        } finally {
            image.close();
        }
    }

    private void onSurfaceFrame(int token, long timestamp) {
        surfaceSamplePending.set(false);
        if (!isCurrent(token))
            return;

        privateFrames++;
        if (privateFirstTimestamp == 0)
            privateFirstTimestamp = timestamp;
        if (privateLastTimestamp > 0 && timestamp > privateLastTimestamp)
            privateTimedFrames++;
        privateLastTimestamp = timestamp;
        privateAccepted = true;
        maybeCompleteCamera(token);
    }

    private void onYuvImage(int token, String id, ImageReader source) {
        Image image = source.acquireLatestImage();
        if (image == null)
            return;

        try {
            if (!isCurrent(token) || yuvAccepted)
                return;
            yuvFrames++;
            if (!needsFullValidation()) {
                if (++frameCount < SETTLE_FRAMES)
                    return;
                yuvResult = analyzeYuv(image);
                yuvAccepted = true;
                maybeCompleteCamera(token);
                return;
            }
            if (!exposureWarm) {
                warmupFrames++;
                if ((warmupFrames >= MIN_WARMUP_FRAMES
                                && stableSensorFrames >= SENSOR_STABLE_FRAMES)
                        || warmupFrames >= MAX_WARMUP_FRAMES) {
                    exposureWarm = true;
                    exposureStageFrames = 0;
                    Log.i(TAG, "WARMUP id=" + id + " frames=" + warmupFrames
                            + " stableSensorFrames=" + stableSensorFrames
                            + " exposureNs=" + warmupExposureTime
                            + " sensitivity=" + warmupSensitivity
                            + " frameDurationNs=" + warmupFrameDuration);
                }
                return;
            }
            if (!exposureComplete) {
                handleExposureFrame(token, id, image);
                return;
            }
            if (++frameCount < SETTLE_FRAMES)
                return;

            yuvResult = analyzeYuv(image);
            yuvAccepted = true;
            requestJpeg(token, id);
            maybeCompleteCamera(token);
        } catch (Exception e) {
            failCamera(token, id, "YUV analysis failed: " + compactError(e));
        } finally {
            image.close();
        }
    }

    private void handleExposureFrame(int token, String id, Image image) {
        if (++exposureStageFrames <= EV_SETTLE_FRAMES)
            return;

        exposureSampleSum += sampledLumaMean(image);
        exposureSampleCount++;
        if (exposureSampleCount < EV_SAMPLE_FRAMES)
            return;

        exposureMeans[exposureStage] = exposureSampleSum / exposureSampleCount;
        exposureStage++;
        exposureStageFrames = 0;
        exposureSampleCount = 0;
        exposureSampleSum = 0.0;

        if (exposureStage < exposureRequests.length) {
            currentExposureCompensation = exposureRequests[exposureStage];
            try {
                applyAutomaticControls(previewRequest, false);
                session.setRepeatingRequest(previewRequest.build(),
                        captureCallback(token), handler);
            } catch (Exception e) {
                failCamera(token, id,
                        "exposure update failed: " + compactError(e));
            }
            return;
        }

        double baseline = (exposureMeans[0] + exposureMeans[2]
                + exposureMeans[4]) / 3.0;
        double negativeRatio = exposureMeans[1] / baseline;
        double positiveRatio = exposureMeans[3] / baseline;
        boolean pixelMovement = negativeRatio < 0.90 && positiveRatio > 1.05;
        boolean sensorLimited = !pixelMovement && stageAtSensorLimit(3)
                && stageAtSensitivityLimit(3);
        boolean valid = pixelMovement || sensorLimited;
        exposureResult = String.format(Locale.US,
                "evValid=%s evPixelMovement=%s evSensorLimited=%s "
                        + "evRequests=%s evStep=%s evMeans=%s "
                        + "evNegativeRatio=%.3f evPositiveRatio=%.3f "
                        + "sensorExposureNs=%s sensorSensitivity=%s "
                        + "sensorFrameDurationNs=%s selectedFps=%s",
                valid, pixelMovement, sensorLimited,
                Arrays.toString(exposureRequests), exposureStep,
                Arrays.toString(exposureMeans), negativeRatio, positiveRatio,
                Arrays.toString(sensorExposureTimes),
                Arrays.toString(sensorSensitivities),
                Arrays.toString(sensorFrameDurations), selectedFpsRange);
        Log.i(TAG, "EXPOSURE id=" + id + " " + exposureResult);
        exposureComplete = true;
        frameCount = 0;
    }

    private boolean stageAtSensorLimit(int stage) {
        if (sensorExposureTimes == null || sensorSensitivities == null
                || sensorFrameDurations == null
                || stage < 0 || stage >= sensorExposureTimes.length)
            return false;

        long exposure = sensorExposureTimes[stage];
        long frameDuration = sensorFrameDurations[stage];
        boolean frameLimited = exposure > 0 && frameDuration > 0
                && exposure >= frameDuration * 0.97;
        boolean rangeLimited = sensorExposureRange != null
                && sensorExposureRange.getUpper() > 0
                && exposure >= sensorExposureRange.getUpper() * 0.97;
        return sensorSensitivities[stage] > 0 && (frameLimited || rangeLimited);
    }

    private boolean stageAtSensitivityLimit(int stage) {
        if (sensorSensitivityRange == null || sensorSensitivities == null
                || stage < 0 || stage >= sensorSensitivities.length)
            return false;
        return sensorSensitivities[stage] >=
                sensorSensitivityRange.getUpper() * 0.97;
    }

    private static boolean closeEnough(long value, long reference) {
        if (value <= 0 || reference <= 0)
            return value == reference;
        return Math.abs(value - reference) <= Math.max(1L, reference / 200L);
    }

    private static Range<Integer> choosePreviewFpsRange(Range<Integer>[] ranges) {
        if (ranges == null || ranges.length == 0)
            return null;

        Range<Integer> best = null;
        for (Range<Integer> candidate : ranges) {
            if (candidate == null || candidate.getLower() <= 0
                    || candidate.getUpper() < candidate.getLower())
                continue;
            if (best == null
                    || candidate.getUpper() > best.getUpper()
                    || (candidate.getUpper().equals(best.getUpper())
                            && candidate.getLower() < best.getLower()))
                best = candidate;
        }
        return best;
    }

    /**
     * Prefer a stable 30 FPS target for the recording-template comparison.
     * Never invent a range that the camera did not advertise: if 30 FPS is
     * unavailable, use the narrowest advertised range containing 30, then a
     * fixed range at or below 30, and finally the ordinary preview choice.
     */
    private static Range<Integer> chooseRecordFpsRange(Range<Integer>[] ranges) {
        if (ranges == null || ranges.length == 0)
            return null;

        Range<Integer> fixedAtOrBelow30 = null;
        Range<Integer> around30 = null;
        for (Range<Integer> candidate : ranges) {
            if (candidate == null || candidate.getLower() <= 0
                    || candidate.getUpper() < candidate.getLower())
                continue;

            int lower = candidate.getLower();
            int upper = candidate.getUpper();
            if (lower == 30 && upper == 30)
                return candidate;

            if (lower == upper && upper <= 30
                    && (fixedAtOrBelow30 == null
                            || upper > fixedAtOrBelow30.getUpper()))
                fixedAtOrBelow30 = candidate;

            if (lower <= 30 && upper >= 30
                    && (around30 == null
                            || upper - lower < around30.getUpper() - around30.getLower()))
                around30 = candidate;
        }

        if (around30 != null)
            return around30;
        if (fixedAtOrBelow30 != null)
            return fixedAtOrBelow30;
        return choosePreviewFpsRange(ranges);
    }

    private void requestJpeg(int token, String id) {
        if (!isCurrent(token) || jpegRequested)
            return;
        jpegRequested = true;
        try {
            CaptureRequest.Builder still = camera.createCaptureRequest(
                    CameraDevice.TEMPLATE_STILL_CAPTURE);
            still.addTarget(jpegReader.getSurface());
            applyAutomaticControls(still, false);
            still.set(CaptureRequest.JPEG_QUALITY, (byte) 90);
            session.capture(still.build(), captureCallback(token), handler);
        } catch (Exception e) {
            failCamera(token, id, "JPEG request failed: " + compactError(e));
        }
    }

    private void onJpegImage(int token, String id, ImageReader source) {
        Image image = source.acquireLatestImage();
        if (image == null)
            return;
        try {
            if (!isCurrent(token) || jpegAccepted)
                return;
            jpegResult = analyzeJpeg(image);
            saveJpeg(id, image);
            jpegAccepted = true;
            maybeCompleteCamera(token);
        } catch (Exception e) {
            failCamera(token, id, "JPEG analysis failed: " + compactError(e));
        } finally {
            image.close();
        }
    }

    private void maybeCompleteCamera(int token) {
        if (!isCurrent(token) || !privateAccepted
                || (needsYuv() && !yuvAccepted)
                || (needsJpeg() && !jpegAccepted)
                || (needsEncodedVideo() && !recorderAccepted))
            return;

        if (needsManualFocus()) {
            if (manualFocusSupported && !manualFocusComplete)
                return;
            if (!manualFocusSupported && privateFrames < MANUAL_FOCUS_SETTLE_FRAMES)
                return;

            String id = cameraIds[cameraIndex];
            boolean valid = !manualFocusSupported
                    || (manualFocusFirstObserved && manualFocusSecondObserved
                            && Float.isFinite(manualFocusFirstDistance)
                            && Float.isFinite(manualFocusSecondDistance)
                            && Math.abs(manualFocusSecondDistance
                                    - manualFocusFirstDistance) >= 0.25f);
            String result = String.format(Locale.US,
                    "CAMERA id=%s valid=%s profile=%s privateFrames=%d "
                            + "manualFocusSupported=%s manualFocusDistanceMax=%.3f "
                            + "manualFocusResult=[%.3f,%.3f] manualFocusDelta=%.3f",
                    id, valid, profile, privateFrames, manualFocusSupported,
                    manualFocusDistanceMax, manualFocusFirstDistance,
                    manualFocusSecondDistance,
                    manualFocusSecondDistance - manualFocusFirstDistance);
            results.add(result);
            Log.i(TAG, result);
            completeCamera(token);
            return;
        }

        if (privateTimedFrames < MIN_PRIVATE_TIMING_FRAMES)
            return;

        if (needsSurface() && surfacePixelResult == null) {
            if (!surfacePixelSamplePending)
                requestSurfacePixelSample(token);
            return;
        }

        boolean autofocusRequired =
                selectedAfMode == CaptureRequest.CONTROL_AF_MODE_AUTO;
        boolean autofocusTerminal = !autofocusRequired
                || afStates.contains(CaptureResult.CONTROL_AF_STATE_FOCUSED_LOCKED)
                || afStates.contains(CaptureResult.CONTROL_AF_STATE_NOT_FOCUSED_LOCKED);
        if (!autofocusTerminal)
            return;

        String id = cameraIds[cameraIndex];
        boolean valid;
        String result;
        if (needsFullValidation()) {
            valid = yuvResult.contains("valid=true")
                    && jpegResult.contains("valid=true") && privateFrames > 0
                    && autofocusTerminal && exposureResult.contains("evValid=true")
                    && exposureMetadata.contains(exposureRequests[0])
                    && exposureMetadata.contains(exposureRequests[1])
                    && exposureMetadata.contains(exposureRequests[3]);
            result = String.format(Locale.US,
                    "CAMERA id=%s valid=%s %s %s privateFrames=%d afMode=%d "
                            + "privateSize=%s %s %s afStates=%s afRegion=%s "
                            + "aeMetadata=%s %s surfacePixels=%s",
                    id, valid, yuvResult, jpegResult, privateFrames, selectedAfMode,
                    privateStreamSize, privateTiming(), captureTiming(),
                    afStates, focusRegions == null ? "none" : focusRegions[0].toString(),
                    exposureMetadata, exposureResult,
                    needsSurface() ? surfacePixelResult : "not-requested");
        } else {
            valid = privateAccepted && (!needsYuv() || yuvResult.contains("valid=true"))
                    && autofocusTerminal
                    && (!needsEncodedVideo() || recorderAccepted);
            result = String.format(Locale.US,
                    "CAMERA id=%s valid=%s profile=%s template=%s privateFrames=%d "
                            + "afMode=%d privateSize=%s %s %s afStates=%s afRegion=%s "
                            + "yuv=%s surfacePixels=%s encoded=%s",
                    id, valid, profile, captureTemplateName(), privateFrames,
                    selectedAfMode,
                    privateStreamSize, privateTiming(), captureTiming(), afStates,
                    focusRegions == null ? "none" : focusRegions[0].toString(),
                    needsYuv() ? yuvResult : "not-requested",
                    needsSurface() ? surfacePixelResult : "not-requested",
                    needsEncodedVideo() ? recorderResult : "not-requested");
        }
        results.add(result);
        Log.i(TAG, result);
        completeCamera(token);
    }

    /**
     * Take one asynchronous readback of the displayed private stream. The
     * surface profile normally measures only TextureView update callbacks;
     * this sample adds colour-order evidence without putting a readback in
     * the repeating capture path.
     */
    private void requestSurfacePixelSample(int token) {
        surfacePixelSamplePending = true;
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            surfacePixelSamplePending = false;
            surfacePixelResult = "surfacePixels=unavailable reason=api-too-old";
            maybeCompleteCamera(token);
            return;
        }

        if (previewSurface == null || privateStreamSize == null) {
            surfacePixelSamplePending = false;
            surfacePixelResult = "surfacePixels=unavailable reason=no-surface";
            maybeCompleteCamera(token);
            return;
        }

        Bitmap bitmap;
        try {
            bitmap = Bitmap.createBitmap(privateStreamSize.getWidth(),
                    privateStreamSize.getHeight(), Bitmap.Config.ARGB_8888);
            PixelCopy.request(previewSurface, bitmap, status -> {
                surfacePixelSamplePending = false;
                if (!isCurrent(token)) {
                    bitmap.recycle();
                    return;
                }
                if (status == PixelCopy.SUCCESS) {
                    String stats = analyzeSurfaceBitmap(bitmap);
                    String filename = "surface-camera-" + cameraIds[cameraIndex] + ".png";
                    try (FileOutputStream output = new FileOutputStream(
                            new File(getFilesDir(), filename))) {
                        if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
                            throw new IllegalStateException("bitmap compression failed");
                        surfacePixelResult = stats + " surfaceImage=" + filename;
                    } catch (Exception error) {
                        surfacePixelResult = stats + " surfaceImage=unavailable reason="
                                + compactError(error);
                    }
                } else
                    surfacePixelResult = "surfacePixels=unavailable pixelCopyStatus=" + status;
                bitmap.recycle();
                maybeCompleteCamera(token);
            }, handler);
        } catch (Throwable error) {
            surfacePixelSamplePending = false;
            surfacePixelResult = "surfacePixels=unavailable error="
                    + compactError(error);
            maybeCompleteCamera(token);
        }
    }

    private static String analyzeSurfaceBitmap(Bitmap bitmap) {
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        int step = Math.max(1, Math.max(width, height) / 128);
        long count = 0;
        long nonBlack = 0;
        long redSum = 0;
        long greenSum = 0;
        long blueSum = 0;
        int redMin = 255;
        int greenMin = 255;
        int blueMin = 255;
        int redMax = 0;
        int greenMax = 0;
        int blueMax = 0;

        for (int y = 0; y < height; y += step) {
            for (int x = 0; x < width; x += step) {
                int color = bitmap.getPixel(x, y);
                int red = (color >> 16) & 0xff;
                int green = (color >> 8) & 0xff;
                int blue = color & 0xff;
                redSum += red;
                greenSum += green;
                blueSum += blue;
                redMin = Math.min(redMin, red);
                greenMin = Math.min(greenMin, green);
                blueMin = Math.min(blueMin, blue);
                redMax = Math.max(redMax, red);
                greenMax = Math.max(greenMax, green);
                blueMax = Math.max(blueMax, blue);
                if (red + green + blue > 12)
                    nonBlack++;
                count++;
            }
        }

        if (count == 0)
            return "surfacePixels=invalid reason=empty-bitmap";

        boolean valid = nonBlack > 0;
        return String.format(Locale.US,
                "surfacePixels=%s surfaceRgbMean=[%.1f,%.1f,%.1f] "
                        + "surfaceRgbRange=[%d-%d,%d-%d,%d-%d] "
                        + "surfaceRgbSamples=%d",
                valid, (double) redSum / count, (double) greenSum / count,
                (double) blueSum / count, redMin, redMax, greenMin, greenMax,
                blueMin, blueMax, count);
    }

    private static String analyzeYuv(Image image) throws Exception {
        PlaneStats y = analyzePlane(image.getPlanes()[0],
                image.getWidth(), image.getHeight());
        PlaneStats u = analyzePlane(image.getPlanes()[1],
                image.getWidth() / 2, image.getHeight() / 2);
        PlaneStats v = analyzePlane(image.getPlanes()[2],
                image.getWidth() / 2, image.getHeight() / 2);
        boolean valid = y.count > 0 && y.max - y.min >= 8
                && y.mean > 2.0 && y.mean < 253.0;

        return String.format(Locale.US,
                "yuvSize=%dx%d yuvValid=%s valid=%s "
                        + "y[min=%d max=%d mean=%.2f sd=%.2f] "
                        + "u[mean=%.2f range=%d] v[mean=%.2f range=%d] ySha256=%s",
                image.getWidth(), image.getHeight(), valid, valid,
                y.min, y.max, y.mean, y.standardDeviation(),
                u.mean, u.max - u.min, v.mean, v.max - v.min, y.digestHex());
    }

    private static String analyzeJpeg(Image image) throws Exception {
        ByteBuffer source = image.getPlanes()[0].getBuffer().duplicate();
        byte[] encoded = new byte[source.remaining()];
        source.get(encoded);
        int length = encoded.length;
        int first = length > 0 ? encoded[0] & 0xff : -1;
        int second = length > 1 ? encoded[1] & 0xff : -1;
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        digest.update(encoded);

        Bitmap bitmap = BitmapFactory.decodeByteArray(encoded, 0, encoded.length);
        int width = bitmap == null ? 0 : bitmap.getWidth();
        int height = bitmap == null ? 0 : bitmap.getHeight();
        int rowJumps = 0;
        double maxRowJump = 0.0;
        if (bitmap != null && width > 0 && height > 0) {
            int sampleStep = Math.max(1, width / 160);
            double previousRed = 0.0;
            double previousGreen = 0.0;
            double previousBlue = 0.0;
            for (int y = 0; y < height; ++y) {
                long redSum = 0;
                long greenSum = 0;
                long blueSum = 0;
                int count = 0;
                for (int x = 0; x < width; x += sampleStep) {
                    int color = bitmap.getPixel(x, y);
                    redSum += (color >> 16) & 0xff;
                    greenSum += (color >> 8) & 0xff;
                    blueSum += color & 0xff;
                    count++;
                }

                double red = (double) redSum / count;
                double green = (double) greenSum / count;
                double blue = (double) blueSum / count;
                if (y > 0) {
                    double jump = (Math.abs(red - previousRed)
                            + Math.abs(green - previousGreen)
                            + Math.abs(blue - previousBlue)) / 3.0;
                    maxRowJump = Math.max(maxRowJump, jump);
                    if (jump > 45.0)
                        rowJumps++;
                }
                previousRed = red;
                previousGreen = green;
                previousBlue = blue;
            }
            bitmap.recycle();
        }

        int rowJumpLimit = Math.max(8, height / 20);
        boolean visualValid = bitmap != null && width > 0 && height > 0
                && rowJumps <= rowJumpLimit;
        boolean valid = length > 128 && first == 0xff && second == 0xd8
                && visualValid;
        return String.format(Locale.US,
                "jpegValid=%s valid=%s jpegBytes=%d jpegSize=%dx%d "
                        + "jpegRowJumps=%d/%d jpegMaxRowJump=%.1f jpegSha256=%s",
                valid, valid, length, width, height, rowJumps, rowJumpLimit,
                maxRowJump, hex(digest.digest()));
    }

    private void saveJpeg(String id, Image image) throws Exception {
        ByteBuffer source = image.getPlanes()[0].getBuffer().duplicate();
        byte[] bytes = new byte[source.remaining()];
        source.get(bytes);
        try (FileOutputStream output = new FileOutputStream(
                new File(getFilesDir(), "camera-" + id + ".jpg"))) {
            output.write(bytes);
        }
    }

    private static PlaneStats analyzePlane(Image.Plane plane, int width, int height)
            throws Exception {
        ByteBuffer bytes = plane.getBuffer().duplicate();
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        PlaneStats stats = new PlaneStats(digest);
        int rowStride = plane.getRowStride();
        int pixelStride = plane.getPixelStride();

        for (int y = 0; y < height; ++y) {
            int row = y * rowStride;
            for (int x = 0; x < width; ++x) {
                int offset = row + x * pixelStride;
                if (offset >= bytes.limit())
                    break;
                stats.add(bytes.get(offset) & 0xff);
            }
        }
        stats.finish();
        return stats;
    }

    private static double sampledLumaMean(Image image) {
        Image.Plane plane = image.getPlanes()[0];
        ByteBuffer bytes = plane.getBuffer().duplicate();
        int rowStride = plane.getRowStride();
        int pixelStride = plane.getPixelStride();
        long sum = 0;
        long count = 0;

        for (int y = 0; y < image.getHeight(); y += 4) {
            int row = y * rowStride;
            for (int x = 0; x < image.getWidth(); x += 4) {
                int offset = row + x * pixelStride;
                if (offset >= bytes.limit())
                    break;
                sum += bytes.get(offset) & 0xff;
                count++;
            }
        }
        return count == 0 ? 0.0 : (double) sum / count;
    }

    private boolean isCurrent(int token) {
        return token == generation && !cameraCompleting;
    }

    private void completeCamera(int token) {
        if (!isCurrent(token))
            return;
        cameraCompleting = true;
        cancelTimeout();
        closeCamera(() -> {
            cameraIndex++;
            handler.postDelayed(this::startNextCamera, 750);
        });
    }

    private void failCamera(int token, String id, String message) {
        if (!isCurrent(token))
            return;
        cameraCompleting = true;
        String result = "CAMERA id=" + id + " valid=false error=" + message;
        results.add(result);
        Log.e(TAG, result);
        cancelTimeout();
        closeCamera(() -> {
            cameraIndex++;
            handler.postDelayed(this::startNextCamera, 750);
        });
    }

    private void finishProbe(String fatal) {
        cameraCompleting = true;
        generation++;
        if (fatal != null) {
            results.add("FATAL " + fatal);
            Log.e(TAG, "FATAL " + fatal);
        }
        closeCamera(null);

        int valid = 0;
        for (String result : results) {
            if (!result.startsWith("CAMERA "))
                continue;
            int status = result.indexOf(" valid=");
            if (status >= 0 && result.startsWith("true", status + 7))
                valid++;
        }
        String summary = needsFullValidation()
                ? "PROBE_DONE valid=" + valid + " total=" + cameraIds.length
                : "PROBE_DONE profile=" + profile + " valid=" + valid
                        + " total=" + cameraIds.length;
        results.add(summary);
        Log.i(TAG, summary);

        try (FileOutputStream output = new FileOutputStream(
                new File(getFilesDir(), "result.txt"))) {
            for (String result : results) {
                output.write(result.getBytes("UTF-8"));
                output.write('\n');
            }
        } catch (Exception e) {
            Log.e(TAG, "could not write result: " + compactError(e));
        }

        runOnUiThread(this::finish);
    }

    private void cancelTimeout() {
        if (timeout != null && handler != null)
            handler.removeCallbacks(timeout);
        timeout = null;
    }

    private void closeCamera(Runnable continuation) {
        cancelTimeout();
        if (recorderStop != null && handler != null)
            handler.removeCallbacks(recorderStop);
        recorderStop = null;
        if (session != null) {
            try {
                session.stopRepeating();
                if (!needsEncodedVideo())
                    session.abortCaptures();
            } catch (Exception e) {
                Log.w(TAG, "capture shutdown: " + compactError(e));
            }
            session.close();
            session = null;
        }
        if (recorderStarted && mediaRecorder != null) {
            try {
                mediaRecorder.stop();
            } catch (Throwable error) {
                Log.w(TAG, "recorder shutdown: " + compactError(error));
            }
            recorderStarted = false;
        }
        previewRequest = null;
        if (closingCamera != null) {
            // A previous close is still completing. Keep only the newest
            // continuation; all callers are on the camera handler thread.
            cameraCloseContinuation = continuation;
            return;
        }

        CameraDevice closing = camera;
        camera = null;
        if (closing != null) {
            closingCamera = closing;
            cameraCloseContinuation = continuation;
            final int closeGeneration = ++cameraCloseGeneration;
            cameraCloseTimeout = () -> {
                if (cameraCloseGeneration == closeGeneration) {
                    Log.w(TAG, "camera close callback timed out; releasing probe resources");
                    finishCameraClose(closing);
                }
            };
            if (handler != null)
                handler.postDelayed(cameraCloseTimeout, CAMERA_TIMEOUT_MS);
            closing.close();
            return;
        }

        releaseCaptureResources();
        if (continuation != null)
            continuation.run();
    }

    private void finishCameraClose(CameraDevice closed) {
        if (closingCamera == null || (closed != null && closed != closingCamera))
            return;
        if (cameraCloseTimeout != null && handler != null)
            handler.removeCallbacks(cameraCloseTimeout);
        cameraCloseTimeout = null;
        closingCamera = null;
        releaseCaptureResources();
        Runnable continuation = cameraCloseContinuation;
        cameraCloseContinuation = null;
        if (continuation != null)
            continuation.run();
    }

    private void releaseCaptureResources() {
        if (yuvReader != null) {
            yuvReader.close();
            yuvReader = null;
        }
        if (jpegReader != null) {
            jpegReader.close();
            jpegReader = null;
        }
        if (privateReader != null) {
            privateReader.close();
            privateReader = null;
        }
        if (mediaRecorder != null) {
            mediaRecorder.release();
            mediaRecorder = null;
        }
        if (recorderSurface != null) {
            recorderSurface.release();
            recorderSurface = null;
        }
        encodedFile = null;
        surfaceSamplePending.set(false);
        surfaceToken = 0;
    }

    @Override
    protected void onDestroy() {
        cameraCompleting = true;
        generation++;
        cameraCloseContinuation = null;
        closeCamera(null);
        if (cameraThread != null) {
            cameraThread.quitSafely();
            cameraThread = null;
        }
        if (previewSurface != null) {
            previewSurface.release();
            previewSurface = null;
        }
        super.onDestroy();
    }

    private static Size chooseProbeSize(Size[] sizes) {
        if (sizes == null || sizes.length == 0)
            return null;
        for (Size size : sizes) {
            if (size.getWidth() == 640 && size.getHeight() == 480)
                return size;
        }
        return Arrays.stream(sizes)
                .filter(size -> size.getWidth() >= 320 && size.getHeight() >= 240)
                .min(Comparator.comparingLong(
                        size -> (long) size.getWidth() * size.getHeight()))
                .orElse(sizes[0]);
    }

    private static Size chooseRecordingYuvSize(Size[] sizes) {
        if (sizes == null || sizes.length == 0)
            return null;
        for (Size size : sizes) {
            if (size.getWidth() == 1280 && size.getHeight() == 720)
                return size;
        }
        return chooseProbeSize(sizes);
    }

    /**
     * Request a deliberately useful private preview size for the performance
     * probe. Prefer the historical 1600x1200 mode when an older overlay still
     * advertises it, then the r44 1280x960 cap and its 720p recording peer.
     */
    private static Size choosePrivateProbeSize(Size[] sizes, Size fallback) {
        if (sizes == null || sizes.length == 0)
            return fallback;

        for (Size size : sizes) {
            if (size.getWidth() == 1600 && size.getHeight() == 1200)
                return size;
        }
        for (Size size : sizes) {
            if (size.getWidth() == 1920 && size.getHeight() == 1080)
                return size;
        }
        for (Size size : sizes) {
            if (size.getWidth() == 1280 && size.getHeight() == 960)
                return size;
        }
        for (Size size : sizes) {
            if (size.getWidth() == 1280 && size.getHeight() == 720)
                return size;
        }

        Size best = Arrays.stream(sizes)
                .filter(size -> size.getWidth() > 0 && size.getHeight() > 0
                        && (sameAspect(size, 4, 3) || sameAspect(size, 16, 9)))
                .max(Comparator.comparingLong(
                        size -> (long) size.getWidth() * size.getHeight()))
                .orElse(null);
        if (best != null)
            return best;
        return Arrays.stream(sizes)
                .filter(size -> size.getWidth() > 0 && size.getHeight() > 0)
                .max(Comparator.comparingLong(
                        size -> (long) size.getWidth() * size.getHeight()))
                .orElse(fallback);
    }

    private static String normalizeProfile(String requested) {
        if (PROFILE_PREVIEW.equals(requested) || PROFILE_PREVIEW_YUV.equals(requested)
                || PROFILE_SURFACE.equals(requested)
                || PROFILE_SURFACE_YUV.equals(requested)
                || PROFILE_RECORD.equals(requested)
                || PROFILE_RECORD_YUV_720P.equals(requested)
                || PROFILE_ENCODE_720P.equals(requested)
                || PROFILE_TAP_FOCUS.equals(requested)
                || PROFILE_MANUAL_FOCUS.equals(requested))
            return requested;
        return PROFILE_FULL;
    }

    private boolean needsFullValidation() {
        return PROFILE_FULL.equals(profile);
    }

    private boolean needsManualFocus() {
        return PROFILE_MANUAL_FOCUS.equals(profile);
    }

    private long cameraTimeoutMs() {
        return needsFullValidation() ? FULL_CAMERA_TIMEOUT_MS : CAMERA_TIMEOUT_MS;
    }

    private boolean needsYuv() {
        return needsFullValidation() || PROFILE_PREVIEW_YUV.equals(profile)
                || PROFILE_SURFACE_YUV.equals(profile) || needsRecordingYuv720p();
    }

    private boolean needsSurface() {
        return PROFILE_SURFACE.equals(profile) || PROFILE_SURFACE_YUV.equals(profile)
                || needsRecordTemplate();
    }

    private boolean needsRecordTemplate() {
        return PROFILE_RECORD.equals(profile) || needsRecordingYuv720p()
                || needsEncodedVideo();
    }

    private boolean needsRecordingYuv720p() {
        return PROFILE_RECORD_YUV_720P.equals(profile);
    }

    private boolean needsEncodedVideo() {
        return PROFILE_ENCODE_720P.equals(profile);
    }

    private int captureTemplate() {
        return needsRecordTemplate()
                ? CameraDevice.TEMPLATE_RECORD : CameraDevice.TEMPLATE_PREVIEW;
    }

    private String captureTemplateName() {
        return needsRecordTemplate() ? "record" : "preview";
    }

    private boolean needsJpeg() {
        return needsFullValidation();
    }

    private static boolean sameAspect(Size size, int width, int height) {
        return (long) size.getWidth() * height == (long) size.getHeight() * width;
    }

    private String privateTiming() {
        if (privateTimedFrames <= 0 || privateLastTimestamp <= privateFirstTimestamp)
            return "privateFps=unavailable privateIntervalMs=unavailable";

        double spanSeconds = (privateLastTimestamp - privateFirstTimestamp) / 1_000_000_000.0;
        double fps = privateTimedFrames / spanSeconds;
        double intervalMs = (spanSeconds * 1000.0) / privateTimedFrames;
        String source = needsSurface() ? "surface" : "imagereader";
        return String.format(Locale.US,
                "privateFps=%.2f privateIntervalMs=%.2f privateTimingSource=%s",
                fps, intervalMs, source);
    }

    private String captureTiming() {
        String sensor = String.format(Locale.US,
                "sensorExposureMs=%.3f sensorFrameDurationMs=%.3f sensorSensitivity=%d",
                latestSensorExposureTime / 1_000_000.0,
                latestSensorFrameDuration / 1_000_000.0,
                latestSensorSensitivity);
        if (captureTimedFrames <= 0 || captureLastTimestamp <= captureFirstTimestamp)
            return "captureFps=unavailable captureIntervalMs=unavailable " + sensor;

        double spanSeconds =
                (captureLastTimestamp - captureFirstTimestamp) / 1_000_000_000.0;
        double fps = captureTimedFrames / spanSeconds;
        double intervalMs = (spanSeconds * 1000.0) / captureTimedFrames;
        return String.format(Locale.US,
                "captureFps=%.2f captureIntervalMs=%.2f %s",
                fps, intervalMs, sensor);
    }

    private static boolean containsSize(Size[] sizes, Size wanted) {
        if (sizes == null)
            return false;
        for (Size size : sizes) {
            if (size.equals(wanted))
                return true;
        }
        return false;
    }

    private static int chooseAutofocusMode(int[] modes, boolean preferVideo) {
        if (preferVideo && contains(modes, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO))
            return CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO;
        if (contains(modes, CaptureRequest.CONTROL_AF_MODE_AUTO))
            return CaptureRequest.CONTROL_AF_MODE_AUTO;
        if (contains(modes, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE))
            return CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE;
        if (contains(modes, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO))
            return CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO;
        return CaptureRequest.CONTROL_AF_MODE_OFF;
    }

    private static boolean contains(int[] values, int wanted) {
        if (values == null)
            return false;
        for (int value : values) {
            if (value == wanted)
                return true;
        }
        return false;
    }

    private static String compactError(Throwable error) {
        String message = error.getMessage();
        return error.getClass().getSimpleName()
                + (message == null ? "" : ": " + message.replace('\n', ' '));
    }

    private static String hex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte value : bytes)
            result.append(String.format(Locale.US, "%02x", value & 0xff));
        return result.toString();
    }

    private static final class PlaneStats {
        private final MessageDigest digest;
        private long count;
        private long sum;
        private long sumSquares;
        private int min = 255;
        private int max;
        private double mean;
        private byte[] hash;

        PlaneStats(MessageDigest digest) {
            this.digest = digest;
        }

        void add(int value) {
            count++;
            sum += value;
            sumSquares += (long) value * value;
            min = Math.min(min, value);
            max = Math.max(max, value);
            digest.update((byte) value);
        }

        void finish() {
            mean = count == 0 ? 0.0 : (double) sum / count;
            hash = digest.digest();
        }

        double standardDeviation() {
            if (count == 0)
                return 0.0;
            double variance = (double) sumSquares / count - mean * mean;
            return Math.sqrt(Math.max(0.0, variance));
        }

        String digestHex() {
            return hex(hash);
        }
    }
}
