import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:intl/intl.dart';

var Error_Messages = () => {
  0 : "区域解锁成功",
  1 : "错误:文件:$fileName.$fileExt无法识别 或 已经解锁过",
  2 : "错误:文件:$fileName.$fileExt无法打开",
  3 : "备份文件无法创建，请检查文件夹以及执行权限",
};

Future<int> main() async{
  String msg;
  int result = 0;
  try{
    result = await unlock();
  }catch(error){
    result = 999;
    msg = "$error";
  }

  switch(result){
    case 999:
      print("$result $msg");
      break;
    default:
      print("$result");
      msg = Error_Messages()["$result"];
      break;
  }
  
  return result;
}

const NEW_FILE_EXTENSION = "new";
const BAK_FILE_EXTENSION = "bak";
const CONFIG_FILE_PATH = "csp_unlocker.conf";
const BUFFER_LENGTH = 1000;

String fileName = "";
String fileExt= "";
List<int> targetBytes = new List<int>();
List<int> replaceBytes = new List<int>();
int bytesLength = 0;
int replaceCount = 0;

Future<int> unlock() async {
  //加载配置文件
  await loadConfig();
  
  printToCMD("读取配置文件完毕，目标:${targetBytes.toBytesString()}");

  //打开文件
  File srcFile = new File("$fileName.$fileExt");
  File newFile = new File("$fileName.$NEW_FILE_EXTENSION");
  RandomAccessFile srcFileAccess;
  RandomAccessFile newFileAccess;

  try{
    srcFileAccess = await srcFile.open();
  }catch(e){
    print("打开文件失败");
    return 2;
  }
  try{
    newFileAccess = await newFile.open(mode: FileMode.write);
  }catch(e){
    print("创建文件失败");
    return 3;
  }

  //创建buffer
  Uint8List bufferBytes;
  int bufferi = 0;
  bool hasReplaced = false;

  //循环对比
  int page = 0;
  int lengthOfFile = srcFileAccess.lengthSync();
  do{
    int remain = lengthOfFile - page * BUFFER_LENGTH;
    int lengthOfRead = math.min(BUFFER_LENGTH,remain);

    bool isFirst = false;
    bool isLast = false;

    if(remain <= BUFFER_LENGTH){
      isLast = true;
    }
    if(srcFileAccess.positionSync() == 0){
      isFirst = true;
      bufferBytes = new Uint8List.fromList(srcFileAccess.readSync(lengthOfRead));
    }else{
      srcFileAccess.setPositionSync(srcFileAccess.positionSync() - bytesLength);
      bufferBytes = srcFileAccess.readSync(lengthOfRead + bytesLength);
    }

    bool matched = false;
    //因为替换只做一次，只哟没有替换过的情况下才循环对比
    //已替换过就跳过对比逻辑，永远都不会匹配:matched = false
    if(hasReplaced == false){
      for(bufferi = 0;bufferi < lengthOfRead;bufferi++){
        if(compareBufferList(bufferBytes,targetBytes,bufferi)){
          //print("[${List<int>.from(bufferBytes.getRange(bufferi,bufferi+bytesLength)).toBytesString()}]  => [${replaceBytes.toBytesString()}]");
          matched = true;
          hasReplaced = true;
          break;
        }
      }
    }

    //判断匹配
    if(matched){
      //匹配情况下，分三部分写入
      newFileAccess.writeFromSync(bufferBytes,0,bufferi);
      newFileAccess.writeFromSync(replaceBytes,0,bytesLength);
      newFileAccess.writeFromSync(bufferBytes,bufferi + bytesLength,bufferBytes.length);
      //由于将当前吧buffer所有都写入新文件，没有预留最后bytelength长度，所以将文件浮标相应后移bytelength
      srcFileAccess.setPositionSync(srcFileAccess.positionSync() + bytesLength);
    }else{
      //不匹配，直接将buffer写入文件（如果不是最后一串buffer，需尾部预留bytelength长度）
      newFileAccess.writeFromSync(bufferBytes,0,(isLast ? bufferBytes.length : lengthOfRead) - (isFirst ? bytesLength : 0));
    }

    page++;
    if(page % 1000 == 0)
      printToCMD("过程: ${page/1000} * 1000KB");

  }while(page*BUFFER_LENGTH < lengthOfFile);
  
  //关闭文件
  await srcFileAccess.close();
  await newFileAccess.close();

  //修改文件名
  //String bakFileExt = await availableBakExt(fileName);
  String bakFileExt = await timeBakExt();
  await srcFile.rename("$fileName.$bakFileExt");
  await newFile.rename("$fileName.$fileExt");

  if(hasReplaced)
    return 0;
  else
    return 1;
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

//对比字节串2
bool compareBufferList(List<int> list1,List<int> list2,int index1){
  for(int i = 0; i < list2.length ; i++){
    if(list1[index1+i] != list2[i]){
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

void printToCMD(String msg){
  //print(msg);
}

//字节串格式化输出扩展
extension BytesList on List{
    String toBytesString()
    {
        String result = "";
        for (var byte in this) {
          result += byte.toRadixString(16);
        }

        return result;
    }
}