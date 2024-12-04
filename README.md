<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

This package allows you to connect to a thermal printer via USB in Flutter Web and print.

It is a fork of [usb_printer_thermal_web](https://github.com/usmannaushahi/usb_thermal_printer_web) and improves upon it and provides more configuration options.

## Features

printFlex: This function accepts a list of string, a list of flex sizes as int and a list of alignments. Using this, you can print any data in tabular form. It takes care of wrapping any long text that does not fit within its flex size.

printText: It allows you to print any text. Configuration options include making the text bold, change alignment or double its size (make it a title).

printEmptyLine: It prints an empty line to create add a space between two printed statements

printDottedLine: It prints a dotted line or you can use it as a divider

printKeyValue: It takes two inputs and prints them as separate columns within a row.

printBarcode: It prints the barcode and prints the given barcode String beneath the barcode.

## Getting started

You should have a web project as this package only supports Flutter Web for now. Before starting the printing, you need to call the pairDevice() function.
You can **optionally** provide the vendorId, productId, interfaceNumber and endpointNumber. If you do not pass these variables, you can still select a device from the list of all connected USB devices and it will automatically try to determine these variables.

## Usage

The function below prints a sample receipt. A fully functional example is present in the `example` directory. Simply clone the package, `cd` into the example directory and run `flutter run -d chrome` to test locally.

```dart
//Create an instance of printer
WebThermalPrinter _printer = WebThermalPrinter();

printReceipt() async {
  await _printer.pairDevice();

  await _printer.printText('Sebastien Brocard',
      bold: true, align: 'center', title: true);
  await _printer.printEmptyLine();

  await _printer.printKeyValue("Products", "Sale");
  await _printer.printEmptyLine();

  for (int i = 0; i < 2; i++) {
    await _printer.printKeyValue(
        'A big title very big title ${i + 1}', '${(i + 1) * 510}.00 AED');
    await _printer.printEmptyLine();
  }

  await _printer.printFlex(
      ['Chocolate Truffle Cake Small', '1', '550.85', '550.85'],
      [4, 1, 2, 2],
      ['left', 'right', 'right', 'right']);

  await _printer.printFlex(
      ['Chocolate Truffle Cake Small', '1', '550.85', '550.85'],
      [4, 1, 2, 2],
      ['left', 'right', 'right', 'right']);

  await _printer.printFlex(
      ['Chocolate Truffle Cake Small', '1', '550.85', '550.85'],
      [4, 1, 2, 2],
      ['left', 'right', 'right', 'right']);

  await _printer.printDottedLine();

  await _printer.printBarcode('123456');

  await _printer.printEmptyLine();
  await _printer.closePrinter();
}
```
