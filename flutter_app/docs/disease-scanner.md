# Disease Scanner — Model Sourcing

The disease scanner screen and API endpoints (`POST /disease-scans`, `GET /disease-scans`) are wired up, but this repo does not bundle a trained model. Before scanning is functional end-to-end:

1. Source or train a crop-disease classification model and export it as TensorFlow Lite (`.tflite`).
2. Drop the file into `flutter_app/assets/models/` (e.g. `crop_disease_v1.tflite`) and add a matching labels file (`crop_disease_v1_labels.txt`, one label per line).
3. Update `DiseaseScanService.predict()` in `lib/src/services/disease_scan_service.dart` with the actual model/labels filenames and input tensor shape.
4. Until then, `predict()` returns a stub result (`modelBundled: false`) so the rest of the flow (camera/gallery capture, history list, API save) can be exercised without a real model.
