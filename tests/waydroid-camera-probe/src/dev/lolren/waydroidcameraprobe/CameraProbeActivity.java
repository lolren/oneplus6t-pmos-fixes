package dev.lolren.waydroidcameraprobe;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.ImageFormat;
import android.graphics.Rect;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.CaptureResult;
import android.hardware.camera2.TotalCaptureResult;
import android.hardware.camera2.params.MeteringRectangle;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.util.Log;
import android.util.Range;
import android.util.Rational;
import android.util.Size;

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

public final class CameraProbeActivity extends Activity {
    private static final String TAG = "WaydroidCameraProbe";
    private static final int SETTLE_FRAMES = 6;
    private static final int EV_SETTLE_FRAMES = 60;
    private static final int EV_SAMPLE_FRAMES = 8;
    private static final int MIN_WARMUP_FRAMES = 30;
    private static final int MAX_WARMUP_FRAMES = 360;
    private static final int SENSOR_STABLE_FRAMES = 20;
    private static final int MIN_PRIVATE_TIMING_FRAMES = 30;
    private static final long CAMERA_TIMEOUT_MS = 120000;

    private final List<String> results = new ArrayList<>();
    private final Set<Integer> afStates = new TreeSet<>();
    private HandlerThread cameraThread;
    private Handler handler;
    private CameraManager manager;
    private String[] cameraIds = new String[0];
    private int cameraIndex;
    private int generation;
    private int frameCount;
    private int privateFrames;
    private int privateTimedFrames;
    private long privateFirstTimestamp;
    private long privateLastTimestamp;
    private Size privateStreamSize;
    private int selectedAfMode;
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
    private boolean cameraCompleting;
    private boolean exposureComplete;
    private boolean yuvAccepted;
    private boolean jpegRequested;
    private boolean jpegAccepted;
    private boolean privateAccepted;
    private String yuvResult;
    private String jpegResult;
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
    private Runnable timeout;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        cameraThread = new HandlerThread("waydroid-camera-probe");
        cameraThread.start();
        handler = new Handler(cameraThread.getLooper());
        manager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);

        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            finishProbe("camera permission was not granted");
            return;
        }

        handler.post(() -> {
            try {
                cameraIds = manager.getCameraIdList();
                Log.i(TAG, "PROBE_START cameras=" + cameraIds.length);
                startNextCamera();
            } catch (Throwable e) {
                finishProbe("enumeration failed: " + compactError(e));
            }
        });
    }

    private void startNextCamera() {
        closeCamera();
        if (cameraIndex >= cameraIds.length) {
            finishProbe(null);
            return;
        }

        final int token = ++generation;
        final String id = cameraIds[cameraIndex];
        frameCount = 0;
        privateFrames = 0;
        privateTimedFrames = 0;
        privateFirstTimestamp = 0;
        privateLastTimestamp = 0;
        privateStreamSize = null;
        cameraCompleting = false;
        yuvAccepted = false;
        jpegRequested = false;
        jpegAccepted = false;
        privateAccepted = false;
        yuvResult = null;
        jpegResult = null;
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
        currentExposureCompensation = 0;
        exposureComplete = false;
        focusRegions = null;
        afStates.clear();
        exposureMetadata.clear();

        try {
            CameraCharacteristics characteristics = manager.getCameraCharacteristics(id);
            StreamConfigurationMap map = characteristics.get(
                    CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
            if (map == null) {
                failCamera(token, id, "missing stream configuration map");
                return;
            }

            Size size = chooseProbeSize(map.getOutputSizes(ImageFormat.YUV_420_888));
            if (size == null) {
                failCamera(token, id, "no YUV_420_888 output size");
                return;
            }
            Size privateSize = choosePrivateProbeSize(
                    map.getOutputSizes(ImageFormat.PRIVATE), size);
            privateStreamSize = privateSize;
            if (!containsSize(map.getOutputSizes(ImageFormat.JPEG), size)) {
                failCamera(token, id, "matching JPEG output size is unavailable");
                return;
            }

            int[] modes = characteristics.get(
                    CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
            selectedAfMode = chooseAutofocusMode(modes);
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
            if (exposureRange == null || exposureStep == null
                    || exposureRange.getLower() >= 0
                    || exposureRange.getUpper() <= 0
                    || exposureStep.doubleValue() <= 0.0) {
                failCamera(token, id, "exposure compensation unavailable: range="
                        + exposureRange + " step=" + exposureStep);
                return;
            }
            exposureRequests = new int[]{0, exposureRange.getLower(), 0,
                    exposureRange.getUpper(), 0};
            exposureMeans = new double[exposureRequests.length];
            sensorExposureTimes = new long[exposureRequests.length];
            sensorSensitivities = new int[exposureRequests.length];
            sensorFrameDurations = new long[exposureRequests.length];
            Range<Integer>[] fpsRanges = characteristics.get(
                    CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES);
            selectedFpsRange = choosePreviewFpsRange(fpsRanges);
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
                    + " probeSize=" + size + " aeRange=" + exposureRange
                    + " aeStep=" + exposureStep
                    + " privateSize=" + privateSize
                    + " fpsRanges=" + Arrays.toString(fpsRanges)
                    + " selectedFps=" + selectedFpsRange
                    + " sensorExposureRangeNs=" + sensorExposureRange
                    + " sensorSensitivityRange=" + sensorSensitivityRange);

            yuvReader = ImageReader.newInstance(
                    size.getWidth(), size.getHeight(), ImageFormat.YUV_420_888, 3);
            jpegReader = ImageReader.newInstance(
                    size.getWidth(), size.getHeight(), ImageFormat.JPEG, 2);
            privateReader = ImageReader.newInstance(
                    privateSize.getWidth(), privateSize.getHeight(),
                    ImageFormat.PRIVATE, 3);
            yuvReader.setOnImageAvailableListener(r -> onYuvImage(token, id, r), handler);
            jpegReader.setOnImageAvailableListener(r -> onJpegImage(token, id, r), handler);
            privateReader.setOnImageAvailableListener(r -> onPrivateImage(token, r), handler);

            timeout = () -> failCamera(token, id,
                    "timed out: yuv=" + yuvAccepted + " jpeg=" + jpegAccepted
                            + " private=" + privateAccepted + "/" + privateFrames
                            + " afStates=" + afStates);
            handler.postDelayed(timeout, CAMERA_TIMEOUT_MS);
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
                    opened.createCaptureSession(Arrays.asList(
                                    privateReader.getSurface(), yuvReader.getSurface(),
                                    jpegReader.getSurface()),
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
                    previewRequest = opened.createCaptureRequest(
                            CameraDevice.TEMPLATE_PREVIEW);
                    previewRequest.addTarget(privateReader.getSurface());
                    previewRequest.addTarget(yuvReader.getSurface());
                    applyAutomaticControls(previewRequest, false);
                    configured.setRepeatingRequest(previewRequest.build(),
                            captureCallback(token), handler);

                    if (selectedAfMode == CaptureRequest.CONTROL_AF_MODE_AUTO) {
                        CaptureRequest.Builder trigger = opened.createCaptureRequest(
                                CameraDevice.TEMPLATE_PREVIEW);
                        trigger.addTarget(privateReader.getSurface());
                        trigger.addTarget(yuvReader.getSurface());
                        applyAutomaticControls(trigger, true);
                        configured.capture(trigger.build(), captureCallback(token), handler);
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
                Integer compensation = result.get(
                        CaptureResult.CONTROL_AE_EXPOSURE_COMPENSATION);
                if (compensation != null)
                    exposureMetadata.add(compensation);
                Long exposureTime = result.get(CaptureResult.SENSOR_EXPOSURE_TIME);
                Integer sensitivity = result.get(CaptureResult.SENSOR_SENSITIVITY);
                Long frameDuration = result.get(CaptureResult.SENSOR_FRAME_DURATION);
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

    private void onYuvImage(int token, String id, ImageReader source) {
        Image image = source.acquireLatestImage();
        if (image == null)
            return;

        try {
            if (!isCurrent(token) || yuvAccepted)
                return;
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
        int neutralLimitCount = 0;
        for (int stage : new int[]{0, 2, 4}) {
            if (stageAtSensorLimit(stage))
                neutralLimitCount++;
        }
        boolean sensorLimited = !pixelMovement && neutralLimitCount >= 2
                && stageAtSensorLimit(3) && neutralSensitivityStable();
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

    private boolean neutralSensitivityStable() {
        int minimum = Integer.MAX_VALUE;
        int maximum = 0;
        for (int stage : new int[]{0, 2, 4}) {
            int sensitivity = sensorSensitivities[stage];
            if (sensitivity <= 0)
                return false;
            minimum = Math.min(minimum, sensitivity);
            maximum = Math.max(maximum, sensitivity);
        }
        return maximum - minimum <= Math.max(1, maximum / 50);
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
        if (!isCurrent(token) || !yuvAccepted || !jpegAccepted || !privateAccepted)
            return;
        if (privateFrames < MIN_PRIVATE_TIMING_FRAMES)
            return;

        boolean autofocusRequired =
                selectedAfMode == CaptureRequest.CONTROL_AF_MODE_AUTO;
        boolean autofocusTerminal = !autofocusRequired
                || afStates.contains(CaptureResult.CONTROL_AF_STATE_FOCUSED_LOCKED)
                || afStates.contains(CaptureResult.CONTROL_AF_STATE_NOT_FOCUSED_LOCKED);
        if (!autofocusTerminal)
            return;

        String id = cameraIds[cameraIndex];
        boolean valid = yuvResult.contains("valid=true")
                && jpegResult.contains("valid=true") && privateFrames > 0
                && autofocusTerminal && exposureResult.contains("evValid=true")
                && exposureMetadata.contains(exposureRequests[0])
                && exposureMetadata.contains(exposureRequests[1])
                && exposureMetadata.contains(exposureRequests[3]);
        String result = String.format(Locale.US,
                "CAMERA id=%s valid=%s %s %s privateFrames=%d afMode=%d "
                        + "privateSize=%s %s afStates=%s afRegion=%s "
                        + "aeMetadata=%s %s",
                id, valid, yuvResult, jpegResult, privateFrames, selectedAfMode,
                privateStreamSize, privateTiming(),
                afStates, focusRegions == null ? "none" : focusRegions[0].toString(),
                exposureMetadata, exposureResult);
        results.add(result);
        Log.i(TAG, result);
        completeCamera(token);
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
        ByteBuffer bytes = image.getPlanes()[0].getBuffer().duplicate();
        int length = bytes.remaining();
        int first = length > 0 ? bytes.get(bytes.position()) & 0xff : -1;
        int second = length > 1 ? bytes.get(bytes.position() + 1) & 0xff : -1;
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        digest.update(bytes);
        boolean valid = length > 128 && first == 0xff && second == 0xd8;
        return "jpegValid=" + valid + " valid=" + valid + " jpegBytes=" + length
                + " jpegSha256=" + hex(digest.digest());
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
        closeCamera();
        cameraIndex++;
        handler.postDelayed(this::startNextCamera, 750);
    }

    private void failCamera(int token, String id, String message) {
        if (!isCurrent(token))
            return;
        cameraCompleting = true;
        String result = "CAMERA id=" + id + " valid=false error=" + message;
        results.add(result);
        Log.e(TAG, result);
        cancelTimeout();
        closeCamera();
        cameraIndex++;
        handler.postDelayed(this::startNextCamera, 750);
    }

    private void finishProbe(String fatal) {
        cameraCompleting = true;
        generation++;
        if (fatal != null) {
            results.add("FATAL " + fatal);
            Log.e(TAG, "FATAL " + fatal);
        }
        closeCamera();

        int valid = 0;
        for (String result : results) {
            if (result.startsWith("CAMERA ")
                    && result.contains(" valid=true yuvSize="))
                valid++;
        }
        String summary = "PROBE_DONE valid=" + valid + " total=" + cameraIds.length;
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

    private void closeCamera() {
        cancelTimeout();
        if (session != null) {
            try {
                session.stopRepeating();
                session.abortCaptures();
            } catch (Exception e) {
                Log.w(TAG, "capture shutdown: " + compactError(e));
            }
            session.close();
            session = null;
        }
        previewRequest = null;
        if (camera != null) {
            camera.close();
            camera = null;
        }
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
    }

    @Override
    protected void onDestroy() {
        cameraCompleting = true;
        generation++;
        closeCamera();
        if (cameraThread != null) {
            cameraThread.quitSafely();
            cameraThread = null;
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

    /**
     * Request a deliberately useful private preview size for the performance
     * probe.  The common 1600x1200 request exercises the Waydroid reduced
     * source-mode path; a smaller YUV probe alone would not.
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

        Size best = Arrays.stream(sizes)
                .filter(size -> size.getWidth() > 1280
                        && size.getHeight() > 720
                        && (sameAspect(size, 4, 3) || sameAspect(size, 16, 9)))
                .min(Comparator.comparingLong(
                        size -> (long) size.getWidth() * size.getHeight()))
                .orElse(null);
        return best == null ? fallback : best;
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
        return String.format(Locale.US, "privateFps=%.2f privateIntervalMs=%.2f",
                fps, intervalMs);
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

    private static int chooseAutofocusMode(int[] modes) {
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
