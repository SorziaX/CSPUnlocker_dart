import 'dart:io';
import 'package:intl/intl.dart';

void main() {
  unlock();
}

const NEW_FILE_EXTENSION = "new";
const BAK_FILE_EXTENSION = "bak";
const CONFIG_FILE_PATH = "csp_unlocker.conf ";

String fileName = "";
String fileExt= "";
List<int> targetBytes = new List<int>();
List<int> replaceBytes = new List<int>();
int bytesLength = 0;
int replaceCount = 0;

Future<void> unlock() async {
  //加载配置文件
  await loadConfig();

  //打开文件
  File srcFile = new File("$fileName.$fileExt");
  File newFile = new File("$fileName.$NEW_FILE_EXTENSION");
  RandomAccessFile srcFileAccess = await srcFile.open();
  RandomAccessFile newFileAccess = await newFile.open(mode: FileMode.write);


  //创建buffer
  List<int> bufferBytes = new List<int>();
  int byte = 0;

  //预读一定长度的buffer，方便对比
  for(int i = 0;i < bytesLength;i++){
    byte = await srcFileAccess.readByteSync();
    bufferBytes.add(byte);
  }


  //循环对比
  do{
    if(replaceCount == 0 && compareList(bufferBytes,targetBytes)){
      //替换字节串
      replaceCount++;
      print("${bufferBytes.toRadix16String()}  => ${replaceBytes.toRadix16String()}");
      for(int i = 0;i < bytesLength;i++){
        byte = await srcFileAccess.readByteSync();
        await newFileAccess.writeByte(replaceBytes[i]);
        bufferBytes.removeAt(0);
        bufferBytes.add(byte);
      }
      continue;
    }else{
      await newFileAccess.writeByte(bufferBytes[0]);
    }

    byte = await srcFileAccess.readByteSync();
    if(byte == -1)
      break;

    bufferBytes.removeAt(0);
    bufferBytes.add(byte);
    
  }while(true);

  //文件已读到底，替换buffer内剩余串
  for(int i = 1;i < bytesLength;i++){
    await newFileAccess.writeByte(bufferBytes[i]);
  }

  //关闭文件
  await srcFileAccess.close();
  await newFileAccess.close();

  //修改文件名
  //String bakFileExt = await availableBakExt(fileName);
  String bakFileExt = await timeBakExt();
  await srcFile.rename("$fileName.$bakFileExt");
  await newFile.rename("$fileName.$fileExt");
}

//对比字节串
bool compareList(List<int> list1,List<int> list2){
  for(int i = 0; i < list1.length ; i++){
    if(list1[i] != list2[i]){
      return false;
    }
  }
  return true;
}

//读取配置文件
void loadConfig() async{
  File config = new File(CONFIG_FILE_PATH);

  List<String> list = await config.readAsLines();
  String targetFileName = list[0];
  int dotIndex = targetFileName.lastIndexOf('.');
  fileName = targetFileName.substring(0,dotIndex);
  fileExt = targetFileName.substring(dotIndex+1,targetFileName.length);

  for(int i = 0; i < list[1].length;i+=2){
    String s2 = list[1].substring(i,i+2);
    int i2 = int.parse(s2,radix: 16);
    targetBytes.add(i2);
  }
  for(int i = 0; i < list[2].length;i+=2){
    String s2 = list[2].substring(i,i+2);
    int i2 = int.parse(s2,radix: 16);
    replaceBytes.add(i2);
  }

  bytesLength = (list[1].length/2).round();
}

//获取可用扩展名
Future<String> availableBakExt(String fileName) async{
  File file;
  String ext;
  int i = 0;
  do{
    ext = "$BAK_FILE_EXTENSION${i == 0 ? '':i}";
    file = new File("$fileName.$ext");
    i++;
  }while(await file.exists());

  return ext;
}

//根据时间生成扩展名
String timeBakExt(){
  var now = DateTime.now();
  var formatter = new DateFormat("yyyy-MM-dd_HH-mm-ss");
  return "${BAK_FILE_EXTENSION}_${formatter.format(now)}";
}


extension BytesList on List{
    String toRadix16String()
    {
        String result = "";
        for (var byte in this) {
          result += byte.toRadixString(16);
        }

        return result;
    }
}