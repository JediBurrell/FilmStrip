# FilmStrip
A cross-platform Dart recreation of [ArkadiusBear/FilmStrip](https://github.com/ArkadiusBear/FilmStrip).

Prerequisites:
* Dart

Running from scratch (on Linux):
```
sudo apt install dart
git clone https://github.com/JediBurrell/FilmStrip.git
cd FilmStrip
dart main.dart ~/video.mp4
```

Here's how the default options would look in a command:

```
dart main.dark --size=medium --ratio=3 --density=200 --orientation=portrait video.mp4
```

Options:

Parameter | Value | Description | Default
--- | --- | --- | ---
--size | small, medium, large | Changes the size of the final export.	| medium
--ratio	| 1-10 | Changes the width or height (based on orientation) relative to the other. | 3
--density	| int | The amount of frames from the source video used in the image. The higher the density the more colors, but also the longer export time	 | 300
--orientation	| portrait, landscape	| What the ratio multiplies. In portrait the color strips are horizontal going down on the image, in landscape they're vertical going from left to right | portrait
--keepFrames | None | If included, the sampling folder will be retained after the process is complete. Running the function again will overwrite this folder.	| None
