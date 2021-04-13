# Roll-API Dart
Dart library for Roll-API

![Pub.dev shield](https://img.shields.io/pub/v/rollapi)


![API available badge](https://img.shields.io/website?down_color=red&label=API&up_color=green&url=https%3A%2F%2Froll.lastgimbus.com%2Fapi%2F)

This icon ↑ indicates if API is working right now

## What the hell is Roll-API??

It's a super cool API that allows you to roll a **real dice** and get it's number!
Check it out: [https://github.com/TheLastGimbus/Roll-API](https://github.com/TheLastGimbus/Roll-API)

![XKCD 221 - random number](images/xkcd_221_random_number.png)

## How to use
1. Import:

   ```dart
   import 'package:rollapi/rollapi.dart' as roll;
   ```
   
2. Simple way - use `getRandomNumber()`:

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
          var sec = (event.value as DateTime).difference(DateTime.now());
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

If you want to use another instance, because you want to test your own or official is currently down, you can:

```dart
import 'package:rollapi/rollapi.dart' as roll;
roll.API_BASE_URL = 'http://192.168.1.100:5000/api/'; 
```