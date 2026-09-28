package com.wwt2.xprinterhotspotlab
import android.Manifest
import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Bundle
import android.text.InputType
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import com.espressif.iot.esptouch.EsptouchTask
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity:AppCompatActivity(){
 private lateinit var ssid:EditText
 private lateinit var pwd:EditText
 private lateinit var ip:EditText
 private lateinit var status:TextView

 override fun onCreate(b:Bundle?){super.onCreate(b)
  val perms=mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
  if(android.os.Build.VERSION.SDK_INT>=33)perms+=Manifest.permission.NEARBY_WIFI_DEVICES
  ActivityCompat.requestPermissions(this,perms.toTypedArray(),9)
  val scroll=ScrollView(this);val root=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(36,42,36,60)}
  fun title(x:String)=TextView(this).apply{text=x;textSize=24f;setPadding(0,12,0,22)}
  fun field(x:String)=EditText(this).apply{hint=x;setPadding(16,14,16,14)}
  fun btn(x:String,fn:()->Unit)=Button(this).apply{text=x;setOnClickListener{fn()}}
  root.addView(title("Xprinter Wi-Fi Setup"))
  root.addView(TextView(this).apply{text="Đưa máy in vào chế độ chờ kết nối Wi-Fi. Nhập SSID và mật khẩu rồi bấm Cấu hình máy in."})
  ssid=field("SSID Wi-Fi");pwd=field("Mật khẩu Wi-Fi").apply{inputType=129}
  root.addView(ssid);root.addView(pwd)
  root.addView(btn("CẤU HÌNH MÁY IN"){configurePrinter()})
  ip=field("IP máy in (tự điền nếu nhận ACK)");root.addView(ip)
  root.addView(btn("TEST TCP 9100"){test(false)})
  root.addView(btn("IN THỬ"){test(true)})
  status=TextView(this).apply{setPadding(0,22,0,0);setTextIsSelectable(true);text="Sẵn sàng"};root.addView(status)
  scroll.addView(root);setContentView(scroll)
 }

 @Suppress("DEPRECATION")
 private fun currentBssid():String?=try{
  val cm=getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
  val n=cm.activeNetwork
  val wi=(n?.let{cm.getNetworkCapabilities(it)}?.transportInfo as? WifiInfo)
    ?: (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).connectionInfo
  wi.bssid?.takeIf{it.isNotBlank()&&it!="02:00:00:00:00:00"&&it!="00:00:00:00:00:00"}
 }catch(_:Throwable){null}

 private fun configurePrinter(){
  val s=ssid.text.toString().trim();val p=pwd.text.toString()
  if(s.isEmpty()){status.text="Nhập SSID Wi-Fi";return}
  val b=currentBssid()
  if(b==null){status.text="Không lấy được BSSID thật của Wi-Fi hiện tại. Không gửi BSSID giả. Bản này dùng SDK ESP-Touch chính thức nên dừng tại đây.";return}
  status.text="Đang cấu hình bằng ESP-Touch chính thức…\nSSID="+s+"\nBSSID="+b
  Thread{
   try{
    val task=EsptouchTask(s,b,p,applicationContext)
    task.setPackageBroadcast(false)
    val r=task.executeForResult()
    runOnUiThread{
     if(r.isSuc){val host=r.inetAddress?.hostAddress.orEmpty();if(host.isNotEmpty())ip.setText(host);status.text="ESP-Touch PASS\nIP="+host+"\nDevice BSSID="+r.bssid}
     else status.text="Không nhận ACK. Chưa kết luận máy in không join mạng."
    }
   }catch(e:Throwable){runOnUiThread{status.text="ESP-Touch ERROR\n"+e.javaClass.simpleName+": "+e.message}}
  }.start()
 }

 private fun test(print:Boolean){
  val h=ip.text.toString().trim();if(h.isEmpty()){status.text="Chưa có IP máy in";return}
  Thread{try{Socket().use{s->s.connect(InetSocketAddress(h,9100),2500);if(print){s.getOutputStream().write("\u001b@XPRINTER LAB\nTCP 9100 PASS\n\n\n".toByteArray());s.getOutputStream().flush()}};runOnUiThread{status.text=if(print)"PRINT SENT PASS" else "TCP 9100 PASS"}}catch(e:Throwable){runOnUiThread{status.text="TCP FAIL: "+e.message}}}.start()
 }
}
