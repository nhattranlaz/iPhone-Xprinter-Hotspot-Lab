package com.wwt2.xprinterhotspotlab
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.*
import android.net.wifi.WifiManager
import android.os.Bundle
import android.text.InputType
import android.widget.*
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.Socket
class MainActivity:AppCompatActivity(){
 lateinit var out:TextView; lateinit var ssid:EditText; lateinit var bssid:EditText; lateinit var pwd:EditText; lateinit var ip:EditText
 override fun onCreate(b:Bundle?){super.onCreate(b); requestPermissions()
  val s=ScrollView(this); val r=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setPadding(32,32,32,48)}
  fun t(x:String)=TextView(this).apply{text=x;textSize=21f;setPadding(0,22,0,12)}
  fun e(x:String)=EditText(this).apply{hint=x}
  fun bt(x:String,f:()->Unit)=Button(this).apply{text=x;setOnClickListener{f()}}
  r.addView(t("1 · Đọc iPhone Hotspot"));r.addView(bt("Đọc SSID / BSSID / IP / Gateway / Prefix"){readWifi()})
  r.addView(t("2 · Đọc Android Hotspot"));r.addView(bt("Đọc interface / tethering runtime"){readRuntime()})
  r.addView(t("3 · Cấu hình Xprinter"));ssid=e("SSID");bssid=e("BSSID (nếu có)");pwd=e("Password").apply{inputType=129};ip=e("IP máy in")
  listOf(ssid,bssid,pwd).forEach{r.addView(it)}
  r.addView(bt("ESP-Touch: cấu hình máy in"){provision()});r.addView(ip)
  r.addView(bt("Test TCP 9100"){test(false)});r.addView(bt("In thử ESC/POS"){test(true)})
  r.addView(t("Diagnostic"));out=TextView(this).apply{setTextIsSelectable(true);typeface=android.graphics.Typeface.MONOSPACE;text="Chưa có dữ liệu"};r.addView(out);s.addView(r);setContentView(s)
 }
 fun requestPermissions(){val p=mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION);if(android.os.Build.VERSION.SDK_INT>=33)p+=Manifest.permission.NEARBY_WIFI_DEVICES;ActivityCompat.requestPermissions(this,p.toTypedArray(),7)}
 @Suppress("DEPRECATION") fun readWifi(){try{
  val cm=getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
  val n=cm.activeNetwork
  val caps=n?.let{cm.getNetworkCapabilities(it)}
  val wi=(caps?.transportInfo as? android.net.wifi.WifiInfo) ?: (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager).connectionInfo
  val lp=n?.let{cm.getLinkProperties(it)}
  val a=lp?.linkAddresses?.firstOrNull{it.address is Inet4Address}
  val g=lp?.routes?.firstOrNull{it.isDefaultRoute}?.gateway?.hostAddress
  val ss=wi.ssid?.trim('"').orEmpty(); val bs=wi.bssid.orEmpty()
  if(ss!="<unknown ssid>")ssid.setText(ss); if(bs!="02:00:00:00:00:00")bssid.setText(bs)
  log("CONNECTED WIFI\\nSSID="+ss+"\\nBSSID="+bs+"\\nIP="+a?.address?.hostAddress+"\\nPREFIX="+a?.prefixLength+"\\nGATEWAY="+g+"\\nFREQ="+wi.frequency+" MHz")
 }catch(e:Throwable){log("WIFI INFO UNAVAILABLE\\n"+e.javaClass.simpleName+": "+e.message+"\\nKiểm tra quyền Nearby devices/Location rồi thử lại.")}}
 fun readRuntime(){try{val cm=getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager;val x=cm.allNetworks.mapNotNull{n->try{val l=cm.getLinkProperties(n)?:return@mapNotNull null;l.interfaceName+": "+l.linkAddresses.joinToString{it.address.hostAddress+"/"+it.prefixLength}}catch(_:Throwable){null}};log("ANDROID RUNTIME\\n"+x.joinToString("\\n")+"\\nUnavailable fields are never fabricated.")}catch(e:Throwable){log("HOTSPOT RUNTIME UNAVAILABLE\\n"+e.javaClass.simpleName+": "+e.message)}}
 fun provision(){val s=ssid.text.toString().trim();if(s.isEmpty()){log("SSID trống");return};log("ESP-Touch starting…");Thread{try{val x=EspTouchV1.provision(this,s,bssid.text.toString().trim(),pwd.text.toString());runOnUiThread{if(x!=null){ip.setText(x);log("ACK RECEIVED IP="+x)}else log("ESP-Touch timeout")}}catch(e:Throwable){runOnUiThread{log("ESP-Touch ERROR "+e.message)}}}.start()}
 fun test(print:Boolean){val h=ip.text.toString().trim();Thread{try{Socket().use{s->s.connect(InetSocketAddress(h,9100),2500);if(print){s.getOutputStream().write("\\u001b@XPRINTER ANDROID HOTSPOT LAB\\nTCP 9100 PASS\\n\\n\\n".toByteArray());s.getOutputStream().flush()}};runOnUiThread{log(if(print)"PRINT SENT PASS" else "TCP 9100 PASS")}}catch(e:Throwable){runOnUiThread{log("FAIL "+e.message)}}}.start()}
 fun log(x:String){out.text=x}
}