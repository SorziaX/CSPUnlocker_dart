import 'dart:io';

void main() {
  test();
}
const SRC_FILE_NAME = "csp";
const SRC_FILE_EXTENSION = "txt";
const NEW_FILE_EXTENSION = "new";
const BAK_FILE_EXTENSION = "bak";
const CONFIG_FILE_PATH = "csp_unlocker.conf ";

Future<void> test() async {
  File srcFile = new File("$SRC_FILE_NAME.$SRC_FILE_EXTENSION");
  File newFile = new File("$SRC_FILE_NAME.$NEW_FILE_EXTENSION");
  File config = new File(CONFIG_FILE_PATH);
  List<String> list = await config.readAsLines();
  RandomAccessFile srcFileAccess = await srcFile.open();
  RandomAccessFile newFileAccess = await newFile.open(mode: FileMode.write);

  int length = (list[0].length/2).round();

  List<int> buffer = new List<int>();
  List<int> target = new List<int>();
  List<int> replace = new List<int>();
  int byte = 0;

  for(int i = 0; i < list[0].length;i+=2){
    String s2 = list[0].substring(i,i+2);
    int i2 = int.parse(s2,radix: 16);
    target.add(i2);
    print(i2.toRadixString(16));
  }print("");
  for(int i = 0; i < list[1].length;i+=2){
    String s2 = list[1].substring(i,i+2);
    int i2 = int.parse(s2,radix: 16);
    replace.add(i2);
    print(i2.toRadixString(16));
  }print("");

  for(int i = 0;i < length;i++){
    byte = await srcFileAccess.readByteSync();
    buffer.add(byte);
  }

  do{
    if(compareList(buffer,target)){
      for(int i = 0;i < length;i++){
        byte = await srcFileAccess.readByteSync();
        await newFileAccess.writeByte(replace[i]);
        print(replace[i].toRadixString(16));
        buffer.removeAt(0);
        buffer.add(byte);
      }
      continue;
    }else{
      await newFileAccess.writeByte(buffer[0]);
    }

    byte = await srcFileAccess.readByteSync();
    if(byte == -1)
      break;

    buffer.removeAt(0);
    buffer.add(byte);
    
  }while(true);

  for(int i = 1;i < length;i++){
    await newFileAccess.writeByte(buffer[i]);
  }

  await srcFileAccess.close();
  await newFileAccess.close();

  await srcFile.rename("$SRC_FILE_NAME.$BAK_FILE_EXTENSION");
  await newFile.rename("$SRC_FILE_NAME.$SRC_FILE_EXTENSION");
}

bool compareList(List<int> list1,List<int> list2){
  for(int i = 0; i < list1.length ; i++){
    if(list1[i] != list2[i]){
      return false;
    }
  }
  return true;
}