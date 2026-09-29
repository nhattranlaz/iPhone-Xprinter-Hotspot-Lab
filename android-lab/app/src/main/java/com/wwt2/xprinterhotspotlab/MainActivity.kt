package com.wwt2.xprinterhotspotlab
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Bundle
import android.provider.Settings
import android.text.InputType
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import com.espressif.iot.esptouch.EsptouchTask
import com.espressif.iot.esptouch.protocol.TouchData
import com.espressif.iot.esptouch.task.EsptouchTaskParameter
import com.espressif.iot.esptouch.task.__EsptouchTask
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity:AppCompatActivity(){
 private lateinit var ssid:EditText; private lateinit var bssid:EditText; private lateinit var pwd:EditText
 private lateinit var noBssid:CheckBox; private lateinit var ip:EditText; private lateinit var status:TextView

 override fun onCreate(b:Bundle?){super.onCreate(b)
  ActivityCompat.requestPermissions(this,arrayOf(Manifest.permission.ACCESS_FINE_LOCATION,Manifest.permission.ACCESS_COARSE_LOCATION),21)
  val scroll=ScrollView(this);val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(36,42,36,60)}
  fun f(h:String)=EditText(this).apply{hint=h;setPadding(14,12,14,12)}
  fun bt(t:String,fn:()->Unit)=Button(this).apply{text=t;setOnClickListener{fn()}}
  root.addView(TextView(this).apply{text="Xprinter Wi-Fi Setup";textSize=25f})
  root.addView(TextView(this).apply{text="Android phải đang kết nối Wi-Fi router. Đưa Xprinter vào chế độ chờ kết nối Wi-Fi."})
  root.addView(bt("ĐỌC WI-FI HIỆN TẠI"){loadWifi()})
  ssid=f("SSID");bssid=f("BSSID thật");pwd=f("Mật khẩu Wi-Fi").apply{inputType=129}
  root.addView(ssid);root.addView(bssid);root.addView(pwd)
  noBssid=CheckBox(this).apply{text="Không gửi BSSID (A/B thử nghiệm)"};root.addView(noBssid)
  root.addView(bt("CẤU HÌNH MÁY IN"){configure()})
  ip=f("IP máy in");root.addView(ip)
  root.addView(bt("TEST TCP 9100"){tcp(false)});root.addView(bt("IN THỬ"){tcp(true)})
  status=TextView(this).apply{setPadding(0,24,0,0);setTextIsSelectable(true);text="Cấp quyền Location, bật Location của Android, rồi bấm ĐỌC WI-FI HIỆN TẠI."};root.addView(status)
  scroll.addView(root);setContentView(scroll)
 }
 override fun onResume(){super.onResume();if(::ssid.isInitialized)loadWifi()}

 @Suppress("DEPRECATION")
 private fun loadWifi(){
  try{
   if(ActivityCompat.checkSelfPermission(this,Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED){status.text="Chưa có quyền Location.";return}
   val lm=getSystemService(Context.LOCATION_SERVICE) as LocationManager
   if(!lm.isLocationEnabled){status.text="Location của Android đang TẮT. Hãy bật Location rồi đọc lại Wi-Fi.";return}
   val wi=(applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).connectionInfo
   val s=wi.ssid?.trim('"').orEmpty();val b=wi.bssid.orEmpty()
   if(s.isNotBlank()&&s!="<unknown ssid>")ssid.setText(s)
   if(b.isNotBlank()&&b!="02:00:00:00:00:00"&&b!="00:00:00:00:00:00")bssid.setText(b)
   status.text="Wi-Fi hiện tại\nSSID="+s+"\nBSSID="+b+"\nFrequency="+wi.frequency+" MHz"
  }catch(e:Throwable){status.text="ĐỌC WI-FI LỖI\n"+e.javaClass.simpleName+": "+e.message}
 }

 private fun configure(){
  val s=ssid.text.toString().trim();val p=pwd.text.toString();val b=bssid.text.toString().trim()
  if(s.isEmpty()){status.text="SSID đang trống.";return}
  if(!noBssid.isChecked && !Regex("(?i)^([0-9a-f]{2}:){5}[0-9a-f]{2}$").matches(b)){status.text="Mode A cần BSSID thật dạng aa:bb:cc:dd:ee:ff. Bấm ĐỌC WI-FI HIỆN TẠI.";return}
  status.text=if(noBssid.isChecked)"MODE B: ESP-Touch chuẩn, BSSID length=0. Đang cấu hình…" else "MODE A: ESP-Touch SDK chính thức + BSSID thật. Đang cấu hình…"
  Thread{
   try{
    val result=if(!noBssid.isChecked){
     EsptouchTask(s,b,p,applicationContext).apply{setPackageBroadcast(false)}.executeForResult()
    }else{
     // Same official Espressif engine/generator. Only BSSID input is empty.
     val param=EsptouchTaskParameter().apply{setBroadcast(false)}
     val task=__EsptouchTask(applicationContext,TouchData(s),TouchData(ByteArray(0)),TouchData(p),null,param)
     task.executeForResult()
    }
    runOnUiThread{
     if(result.isSuc){val h=result.inetAddress?.hostAddress.orEmpty();if(h.isNotEmpty())ip.setText(h);status.text=(if(noBssid.isChecked)"MODE B" else "MODE A")+" ACK PASS\nIP="+h+"\nPrinter BSSID="+result.bssid}
     else status.text=(if(noBssid.isChecked)"MODE B" else "MODE A")+" ACK TIMEOUT\nChưa kết luận provisioning thất bại. Kiểm tra máy in đã join router chưa."
    }
   }catch(e:Throwable){runOnUiThread{status.text="PROVISIONING ERROR\n"+e.javaClass.simpleName+": "+e.message}}
  }.start()
 }
 private fun tcp(print:Boolean){val h=ip.text.toString().trim();if(h.isEmpty()){status.text="Chưa có IP máy in.";return};Thread{try{Socket().use{s->s.connect(InetSocketAddress(h,9100),2500);if(print){s.getOutputStream().write("\u001b@XPRINTER ROUTER LAB\nTCP 9100 PASS\n\n\n".toByteArray());s.getOutputStream().flush()}};runOnUiThread{status.text=if(print)"PRINT PASS" else "TCP 9100 PASS"}}catch(e:Throwable){runOnUiThread{status.text="TCP FAIL: "+e.message}}}.start()}
}