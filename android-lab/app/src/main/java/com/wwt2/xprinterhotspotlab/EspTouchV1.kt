package com.wwt2.xprinterhotspotlab
import android.content.Context
import android.net.wifi.WifiManager
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.MulticastSocket
import java.util.zip.CRC32
object EspTouchV1 {
 fun provision(ctx:Context,ssid:String,bssid:String,password:String):String?{
  val wm=ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
  val lock=wm.createMulticastLock("xprinter-esptouch-lab");lock.setReferenceCounted(false);lock.acquire()
  val listener=DatagramSocket(18266).apply{soTimeout=60000;broadcast=true}
  try{
   val sender=DatagramSocket()
   val guide=intArrayOf(515,514,513,512)
   val started=System.currentTimeMillis()
   while(System.currentTimeMillis()-started<2000){for(n in guide)sendLen(sender,"234.1.1.1",7001,n,8)}
   // Experimental compatibility frame: preserve Wireless Link/ESP-Touch transport behavior.
   // Full datum encoder will be validated against the reference APK before product use.
   val raw=(ssid+"\\u0000"+password+"\\u0000"+bssid).toByteArray(Charsets.UTF_8)
   val phase=System.currentTimeMillis()
   var seq=1
   while(System.currentTimeMillis()-phase<45000){
    for(v in raw){val n=40+((v.toInt() and 255)+seq)%1200;sendLen(sender,"234."+seq+"."+seq+"."+seq,7001,n,8);seq=1+(seq%100)}
   }
   val buf=ByteArray(64);val p=DatagramPacket(buf,buf.size);listener.receive(p)
   return p.address.hostAddress
  }finally{listener.close();lock.release()}
 }
 private fun sendLen(s:DatagramSocket,host:String,port:Int,len:Int,delay:Long){val b=ByteArray(len);s.send(DatagramPacket(b,b.size,InetAddress.getByName(host),port));Thread.sleep(delay)}
}
