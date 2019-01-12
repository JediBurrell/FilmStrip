import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:path/path.dart';
import 'package:image/image.dart';
import 'package:console/console.dart';

var exitCode = 0;

const Map<String, bool> orientations = {
  'portrait': true,
  'landscape': false,
};

const Map<String, int> sizes = {
  'small': 300,
  'medium': 500,
  'large': 1000
};

ArgResults argResults;
File video;

int _width, _height;

Future main(List<String> args) async {

  Console.init();

  ArgParser parser = ArgParser()
    ..addOption('size',
                defaultsTo: 'medium',
                abbr: 's',
                help: 'Size of the exported image. Defaults to medium.',
                valueHelp: 'small, medium, large'
                )
    ..addOption('ratio',
                defaultsTo: '3',
                abbr: 'r',
                help: 'Ratio of width/height. Defaults to 3.',
                valueHelp: '1-10'
                )
    ..addOption('density',
                defaultsTo: '200',
                abbr: 'd',
                help: 'The amount of frames used to create your strip.'
                )
    ..addOption('orientation',
                defaultsTo: 'portrait',
                abbr: 'o',
                help: 'The orientation of the image.',
                valueHelp: 'portrait, landscape'
                )
    ..addFlag('keepFrames', defaultsTo: false, negatable: false)
    ..addCommand('help')..addCommand('h');

  argResults = parser.parse(args);

  Map arguments = createMap(argResults.arguments.toList());
  print(arguments);

  // We can assume that if there's a command, it's help since that's the only one.
  if(argResults.command != null) {
    print(parser.usage);
    exit(0);
  }

  // Check to make sure there's only one parameter.
  _checkForError(argResults.rest);

  // Set the image's width and height.
  if(arguments['orientation']) {
    _width = arguments['size'];
    _height = arguments['size']*arguments['ratio'];

    if(arguments['density'] > _height) {
      stderr.write('Error: density is greater than the height.\nIncrease the size or decrease the density.');
      exit(2);
    }
  } else {
    _width = arguments['size']*arguments['ratio'];
    _height = arguments['size'];

    if(arguments['density'] > _height) {
      stderr.write('Error: density is greater than the width.\nIncrease the size or decrease the density.');
      exit(2);
    }
  }

  // Get the correct path for the video file.
  // If the path is absolute, we keep it, otherwise we convert it relatively.
  if(FileSystemEntity.type(argResults.rest.first)==FileSystemEntityType.notFound)
    video = File(join(dirname(Platform.script.path), argResults.rest.first));
  else
    video = File(argResults.rest.first);
  
  // Check if the path is a valid file.
  _checkForError(video);

  String output = join(dirname(Platform.script.path), basenameWithoutExtension(video.path)+'.png');
  String scriptPath = join(dirname(Platform.script.path), 'tools');
  int videoLength;

  // Get the video length. This'll help us evenly grab the frames.
  await Process.run(scriptPath+'/ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', video.path]).then((value) {
    videoLength = double.parse(value.stdout, (e) {
      stderr.write('Something unkown went wrong, send this to @JediBurrell:\n\n');
      stdout.write('out: ${value.stdout}');
      stderr.write('orr: ${value.stderr}');
      exit(exitCode = 2);
    }).toInt();
    stdout.write('Video length: $videoLength\n');
  });

  // Create temporary direcctory to store frames.
  Directory(dirname(Platform.script.path)+'/tmp').create();

  Image image = Image(_width, _height);

  // Create a progress bar.
  ProgressBar progressBar = ProgressBar();

  for(int i = 0; i < arguments['density']; i++) {

    int currentTime = ((videoLength/arguments['density'])*i).toInt();

    // Save the frame into the temporary directory.
    await Process.run(scriptPath+'/ffmpeg', '-ss $currentTime -i ${video.path} -vframes 3 -y ${dirname(Platform.script.path)}/tmp/f_$i.png'.split(' '))
    .catchError((error) => stderr.write(error));

    Image tmpImage = await decodeImage(File(dirname(Platform.script.path)+'/tmp/f_$i.png').readAsBytesSync());
    int color = copyResize(tmpImage, 1, 1).getPixel(0, 0);

    int x1, x2, y1, y2;

    // This could just be "true", but for readability's sake it's comparing them.
    if(arguments['orientation']==orientations['portrait']) {
      x1 = 0;
      y1 = ((_height/arguments['density'])*i).toInt();
      x2 = _width;
      y2 = ((_height/arguments['density'])*(i+1)).toInt();
    } else {
      x1 = ((_width/arguments['density'])*i).toInt();
      y1 = 0;
      x2 = ((_width/arguments['density'])*(i+1)).toInt();
      y2 = _height;
    }

    for(int x = x1; x < x2; x++) {
      for(int y = y1; y < y2; y++) {
        image.setPixel(x, y, color);
      }
    }

    int progress = (((i+1)/arguments['density'])*100).toInt();
    progressBar.update(progress);

  }

  Directory(dirname(Platform.script.path)+'/exports').create();
  File exportedImage = File('${dirname(Platform.script.path)}/exports/${basenameWithoutExtension(video.path)}.png')..writeAsBytes(encodePng(image));

  stdout.write('Image created at: ${exportedImage.path}');

  // Clean up temporary files.
  if(!argResults.arguments.contains('--keepFrames'))
    Directory(dirname(Platform.script.path)+'/tmp').delete(recursive: true);

}

// Validates options, then returns the value.
MapEntry<String, dynamic> validateOption(String option) {

  if(option.startsWith('--size') || option.startsWith('-s')) {

    String size;
    if(sizes.containsKey(size = option.split('=').last))
      return MapEntry('size', sizes[size]);

    stderr.write('Error: invalid size.');
    exitCode = 2;

  } else if(option.startsWith('--ratio') || option.startsWith('-r')) {

    int ratio = int.parse(option.split('=').last, onError: (e) {
      stderr.write('Error: invalid ratio.');
      exit(exitCode = 2); // Quit prematurely on a fatal error.
    });

    if(ratio <= 10 && ratio >= 1)
      return MapEntry('ratio', ratio);

    stderr.write('Error: ratio out of range (1-10).');
    exitCode = 2;

  } else if(option.startsWith('--density') || option.startsWith('-d')) {

    int density = int.parse(option.split('=').last, onError: (e) {
      stderr.write('Error: invalid ratio.');
      exit(exitCode = 2); // Quit prematurely on fatal error.
    });

    return MapEntry('density', density);

  } else if(option.startsWith('--orientation') || option.startsWith('-o')) {

    String orientation;
    if(orientations.containsKey(orientation = option.split('=').last))
      return MapEntry('orientation', orientations[orientation]);
    
    stderr.write('Error: invalid orientation.');
    exitCode = 2;

  }

  stderr.write('Warning: uknown parameter "$option"\n');
  exitCode = 1;

  return null;

}

// Creates a string key map for easy access to the options.
Map<String, dynamic> createMap(List<String> options) {

  Map<String, dynamic> mappedOptions = Map<String, dynamic>();

  options.takeWhile((option) => option != options.last && option.startsWith('-'))
    .forEach((option) {
      MapEntry<String, dynamic> entry;
      if((entry = validateOption(option)) != null)
        mappedOptions.addEntries([entry]);
    });

  // putIfAbsent has a bug with dynamic object type.
  if(!mappedOptions.containsKey('size')) mappedOptions['size'] = sizes['medium'];
  if(!mappedOptions.containsKey('ratio')) mappedOptions['ratio'] = 3;
  if(!mappedOptions.containsKey('density')) mappedOptions['density'] = 200;
  if(!mappedOptions.containsKey('orientation')) mappedOptions['orientation'] = orientations['portrait'];

  return mappedOptions;

}

void _checkForError(dynamic ip) async {
  switch(ip) {
    case List:

      if(ip.length > 1) {
        stderr.write('Error: too many arguments.\n');
        exitCode = 2;
      }

      break;

    case File:

      if(FileSystemEntity.type(ip) != FileSystemEntityType.file) {
        stderr.write('Error: file must be a video.\n');
        exitCode = 2;
      }

      break;

  }

  if(exitCode>1) exit(exitCode);
}