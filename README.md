# Roll-API Dart
Dart library for Roll-API

## What the hell is Roll-API??

It's a super cool API that allows you to roll a **real dice** and get it's number!
Check it out: [https://github.com/TheLastGimbus/Roll-API](https://github.com/TheLastGimbus/Roll-API)

## How to use
1. `import-as`:

   ```dart
   import 'package:rollapi/rollapi.dart' as roll;
   ```
   
2. Simple way - use `getSimpleResult()`:

   ```dart
   print("Rolling a dice...");
   roll.getSimpleResult().then((result) => print("Number: $result"));
   ```
   
   It returns pure `Future<int>`, and throws an exception if something failed
   
3. More advance way: use `makeRequest()`:
   
   It returns a `Request` object, which contains UUID and Stream of values:

   ```dart
   var request = await roll.makeRequest();
   request.stateStream.listen((event) {
    switch (event.key) {
      case roll.RequestState.queued:
        print('Wating...');
        // .queued value is an ETA DateTime - which can be null
        if (event.value != null) {
          var sec = DateTime.now().difference(event.value as DateTime);
          print('Time left: $sec seconds');
        }
        break;
      case roll.RequestState.failed:
        print('Request failed :(((');
        // .failed value is an exception - you can throw it
        throw event.value;
        break;
      case roll.RequestState.finished:
        print('Finished!!! Number: ${event.value}');
        break;
      default:
        break;
    }
   });
   ```