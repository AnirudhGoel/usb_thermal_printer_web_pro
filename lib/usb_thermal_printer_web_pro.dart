library usb_thermal_printer_web_pro;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:usb_device/usb_device.dart'
    if (dart.library.io) 'usb_device_empty.dart';

class WebThermalPrinter {
  var pairedDevice;
  var interfaceNumber;
  var endpointNumber;
  int printerWidth = 45;
  int leftPad = 3;
  int rightPad = 3;

  final UsbDevice usbDevice = UsbDevice();

  void config({int? printWidth, int? leftPadding, int? rightPadding}) {
    printerWidth = printWidth ?? 30;
    leftPad = leftPadding ?? 5;
    rightPad = rightPadding ?? 5;
  }

  Future<void> printToPaper(String text, {bool newline = true}) async {
    String paddedString = newline
        ? "${' ' * leftPad}${text}${' ' * rightPad}\n"
        : "${' ' * leftPad}${text}${' ' * rightPad}";
    var encodedText = utf8.encode(paddedString);
    var buffer = Uint8List.fromList(encodedText).buffer;
    await usbDevice.transferOut(pairedDevice, endpointNumber, buffer);
  }

  Future<void> pairDevice(
      {int? vendorId,
      int? productId,
      int? interfaceNo,
      int? endpointNo}) async {
    if (!kIsWeb) return;

    if (vendorId == null || productId == null) {
      pairedDevice ??= await usbDevice.requestDevices([]);
    } else {
      pairedDevice ??= await usbDevice.requestDevices(
          [DeviceFilter(vendorId: vendorId, productId: productId)]);
    }

    // USBDeviceInfo deviceInfo =
    //     await usbDevice.getPairedDeviceInfo(pairedDevice); // get device's info
    // print(deviceInfo);

    List<USBConfiguration> availableConfigurations =
        await usbDevice.getAvailableConfigurations(
            pairedDevice); // get device's configurations

    int? autoDetectedInterfaceNumber =
        availableConfigurations[0].usbInterfaces?[0].interfaceNumber;
    int? autoDetectedEndpointNumber = availableConfigurations[0]
        .usbInterfaces?[0]
        .alternatesInterface?[0]
        .endpoints?[0]
        .endpointNumber;

    print(availableConfigurations);

    interfaceNumber = interfaceNo ??
        (autoDetectedInterfaceNumber ?? 0); // By Default, it is usually 0
    endpointNumber = endpointNo ??
        (autoDetectedEndpointNumber ?? 1); // By Default, it is usually 1

    print("Interface Number: ${interfaceNumber}");
    print("Endpoint Number: ${endpointNumber}");

    await usbDevice.open(pairedDevice);
    await usbDevice.claimInterface(pairedDevice, interfaceNumber);
  }

  Future<void> printKeyValue(
    String title,
    String value,
  ) async {
    if (!kIsWeb) return;

    var titleColumnWidth = (printerWidth * 0.65).round();
    var valueColumnWidth = (printerWidth * 0.35).round();

    // Split the title and value into separate rows
    var titleRows = _splitStringIntoRows(title, titleColumnWidth);
    var valueRows = _splitStringIntoRows(value, valueColumnWidth);

    // Print each row separately
    for (var i = 0; i < max(titleRows.length, valueRows.length); i++) {
      var titleRow = titleRows.length > i ? titleRows[i] : '';
      var valueRow = valueRows.length > i ? valueRows[i] : '';

      printToPaper(
          "${titleRow.padRight(titleColumnWidth)}${valueRow.padLeft(valueColumnWidth)}");
    }
  }

  Future<void> printFlex(
    List<String> textList,
    List<int> flexList,
    List<String> alignList,
  ) async {
    if (!kIsWeb) return;

    if (textList.length != flexList.length ||
        textList.length != alignList.length) {
      throw ArgumentError("All input lists must have the same length.");
    }

    int totalFlex = flexList.fold(0, (a, b) => a + b);

    // Calculate column widths
    List<int> columnWidths = flexList
        .map((flex) => (flex * printerWidth / totalFlex).floor())
        .toList();

    // Wrap text into multiple lines if it exceeds column width
    List<List<String>> wrappedRows = [];
    for (int i = 0; i < textList.length; i++) {
      wrappedRows.add(_splitStringIntoRows(textList[i], columnWidths[i]));
    }

    // Determine the maximum number of lines in a row
    int maxLines =
        wrappedRows.map((row) => row.length).reduce((a, b) => a > b ? a : b);

    // Print rows line by line
    for (int line = 0; line < maxLines; line++) {
      String row = "";
      for (int col = 0; col < textList.length; col++) {
        String text =
            (line < wrappedRows[col].length) ? wrappedRows[col][line] : "";
        row += _formatText(text, columnWidths[col], alignList[col]);
      }
      printToPaper(row, newline: false);
    }

    printEmptyLine();
  }

  String _formatText(String text, int width, String alignment) {
    if (alignment == 'right') {
      return text.padLeft(width);
    } else if (alignment == 'center') {
      int padding = (width - text.length) ~/ 2;
      return ' ' * padding + text + ' ' * (width - text.length - padding);
    } else {
      return text.padRight(width); // Default is left alignment
    }
  }

  List<String> _splitStringIntoRows(String str, int rowWidth) {
    var rows = <String>[];
    var currentRow = '';
    for (var word in str.split(' ')) {
      if ((currentRow + word).length > rowWidth) {
        rows.add(currentRow);
        currentRow = '';
      }
      currentRow += word + ' ';
    }
    if (currentRow.isNotEmpty) {
      rows.add(currentRow);
    }
    return rows;
  }

  Future<void> printBarcode(String barcodeData) async {
    if (kIsWeb == false) {
      return;
    }
    var barcodeBytes = Uint8List.fromList([
      0x1d, 0x77, 0x02, // Set barcode height to 64 dots (default is 50 dots)
      0x1d, 0x68, 0x64, // Set barcode text position to below barcode
      0x1d, 0x48, 0x02, // Set barcode text font to Font B (default is Font A)
      0x1d, 0x6b, 0x49, // Print Code 128 barcode with text
      barcodeData.length + 2, // Length of data to follow (barcodeData + {B})
      0x7b, 0x42, // Start Code B
    ]);
    var barcodeStringBytes = utf8.encode(barcodeData);
    var data = Uint8List.fromList([...barcodeBytes, ...barcodeStringBytes]);

    var centerAlignBytes = Uint8List.fromList([
      0x1b, 0x61, 0x01, // Center align
    ]);
    var centerAlignData = centerAlignBytes.buffer.asByteData();
    var resetAlignBytes = Uint8List.fromList([
      0x1b, 0x61, 0x00, // Reset align to left
    ]);
    var resetAlignData = resetAlignBytes.buffer.asByteData();

    await usbDevice.transferOut(
        pairedDevice, endpointNumber, centerAlignData.buffer);
    await usbDevice.transferOut(pairedDevice, endpointNumber, data.buffer);
    await usbDevice.transferOut(
        pairedDevice, endpointNumber, resetAlignData.buffer);
  }

  Future<void> printText(
    String text, {
    bool bold = false,
    String align = 'left',
    bool title = false,
  }) async {
    if (!kIsWeb) return;

    if (bold) {
      var boldBytes = Uint8List.fromList([0x1B, 0x45, 0x01]);
      await usbDevice.transferOut(
          pairedDevice, endpointNumber, boldBytes.buffer);
    }

    if (align == 'center') {
      var centerAlignBytes = Uint8List.fromList([0x1b, 0x61, 0x01]);
      await usbDevice.transferOut(
          pairedDevice, endpointNumber, centerAlignBytes.buffer);
    }

    if (align == 'right') {
      var rightAlignBytes = Uint8List.fromList([0x1B, 0x61, 0x02]);
      await usbDevice.transferOut(
          pairedDevice, endpointNumber, rightAlignBytes.buffer);
    }

    if (title) {
      var doubleSizeBytes = Uint8List.fromList([0x1D, 0x21, 0x11]);
      await usbDevice.transferOut(
          pairedDevice, endpointNumber, doubleSizeBytes.buffer);
    }

    var textRows = title
        ? _splitStringIntoRows(text, (printerWidth / 2).round())
        : _splitStringIntoRows(text, printerWidth);
    // Print each row separately
    for (var i = 0; i < textRows.length; i++) {
      printToPaper(textRows[i]);
    }

    var boldOffBytes = Uint8List.fromList([0x1B, 0x45, 0x00]);
    await usbDevice.transferOut(
        pairedDevice, endpointNumber, boldOffBytes.buffer);

    var leftAlignBytes = Uint8List.fromList([0x1b, 0x61, 0x00]);
    await usbDevice.transferOut(
        pairedDevice, endpointNumber, leftAlignBytes.buffer);

    var normalSizeBytes = Uint8List.fromList([0x1D, 0x21, 0x00]);
    await usbDevice.transferOut(
        pairedDevice, endpointNumber, normalSizeBytes.buffer);
  }

  Future<void> printEmptyLine() async {
    if (!kIsWeb) return;
    printToPaper("");
  }

  Future<void> printDottedLine() async {
    if (!kIsWeb) return;
    // var dottedLine = ''.padRight(printerWidth - leftPad, '-');
    String dottedLine = '_' * (printerWidth - leftPad);
    printText(dottedLine, align: 'center');
    // printToPaper(dottedLine);
  }

  Future<void> closePrinter() async {
    if (!kIsWeb) return;
    await usbDevice.close(pairedDevice);
  }
}
