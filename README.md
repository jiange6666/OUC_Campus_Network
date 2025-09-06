# 中国海洋大学校园网登录工具，多wan聚合自动登录脚本合理提升网速等

## 使用前须知：
1. 此帖主要针对**西海岸校区**，别的校区请自行测试
2. 中国海洋大学有4个校区：**崂山校区**、**鱼山校区**、**浮山校区**、**西海岸校区**。多wan聚合登录脚本在**西海岸校区**实测可用（目前**听海苑**可能有限制不是太好使，后续有时间会继续测试），**崂山校区**实测可以直接设置多wan拨号连接不需要自动登录脚本，鱼山校区和浮山校区没测试过，但是理论上DHCP登录的都可行
3. **西海岸校区**实测最快可以100Mbps左右，就算是5口聚合也是100Mbps左右，原因不明，故性价比最高的是**双口聚合**或**三口聚合**
4. **崂山校区**实测双口聚合可达80Mbps
5. **不同的软件对多wan聚合的识别和兼容性不同**，**甚至测速也不是能完全识别多wan聚合的**
   #### 已知**兼容**的有：
   - Steam
   - Epic Games
   - 暴雪
   - 迅雷
   - 百度网盘
   - 123网盘
   - 三角洲的官方下载器支持，故推测WeGame也支持
   - 火绒应用商店，刚开始下载的时候会支持，然后会慢慢衰减到单wan的速度
   - .......
   #### 已知 **不兼容**的有：
   - 谷歌浏览器
   - edge浏览器
   - 天翼网盘（可能是我没充会员有限速）
   - ......
   #### 会不定期更新兼容软件，具体兼容性请同学们自行测试
6. **不同的openwrt固件**对多wan聚合的效果也有差距，请同学们自行感受
7. **Openwrt路由器**连接校园网之前，请在**网络-DHCP/DNS**中关闭**重绑定保护**，如下图，**否则无法连接校园网**
   <img width="920" height="131" alt="image" src="https://github.com/user-attachments/assets/bb4688b7-06ec-4c2f-bb2b-46434ba22f27" />



## 更新日志
2025.8.23 首次发布
2025.9.4 这些天中间进行了若干次修改，使其功能更完善，修复了脚本bug，增加了更多说明
2025.9.5 升级登录工具，增加跳过ssl验证功能，修复一些bug



## 使用条件;
1. 校园网登录工具exe：**无路由器**，**非openwrt路由器**
2. 多wan聚合自动登录脚本： 多wan聚合自动登录脚本需配合**openwrt系统**的路由器使用，且路由器安装了**mwan3多wan聚合软件包**，并且配置**负载均衡**

##
海大的校园网一个月30元无限量，一个账号可以登3个设备，限速40Mbps，对于现在的时代来说有点慢，如果设备多的话，3个端口还不够用，所以开发了这个通过路由器来聚合自己的端口从而提升网速

## 使用教程
### 一、校园网登录工具exe教程
1. 打开中国海洋大学校园网登录工具exe
2. 如果不用路由器的话，就只需要输一组账号密码，然后获取本机信息，点击开始登录即可
3. 如果使用路由器的话，如下：
   1. 不支持多wan聚合的路由器：只需要输一组账号密码，然后获取本机信息，点击开始登录即可
   2. 有些路由器本身系统支持多wan聚合，如小米AX3000T,TP-LINK XDR3030等，登录方式为DHCP，很多时候弹出的网页只能登一个WAN口，无法有效聚合，故可采用此exe工具进行登录，输入账号密码，输入和账号密码对应的路由器每个WAN口的IP和MAC（**IP必须填，MAC建议用全小写并且去掉冒号**，MAC可填0000000000），然后点击开始登录即可
   3. openwrt系统的路由器：配置好WAN口和负载均衡（网上有教程，有点技术门槛，可自己学习一下），然后输入账号密码，输入和账号密码对应的路由器每个WAN口的IP和MAC，如下图（IP是斜杠之前的，斜杠后面的数字是端口号，**MAC建议用全小写并且去掉冒号**）
      <img width="974" height="309" alt="820f6b35c7046747e80df54e43c15b77" src="https://github.com/user-attachments/assets/4931c55f-4e69-41a2-b8e4-531a276cfae4" />
   4. 有些地方（如西海岸校区的**听海苑**）可能会登不上去，就有可能是**ssl证书**的问题，则可**勾选跳过ssl**再登录

### 二、校园网多wan聚合自动登录脚本教程
1. 多wan聚合自动登录脚本需配合**openwrt系统**的路由器使用，且路由器安装了**mwan3多wan聚合软件包**，并且配置**负载均衡**（自己上网查教程学习）
2. 用winscp，用ssh（scp）连接路由器，将autologin_multi_user.sh上传至root文件夹中
   <img width="425" height="210" alt="image" src="https://github.com/user-attachments/assets/d156cc0c-6201-4cee-b22d-49fe59cb141d" />
3. 在winscp中打开已经上传好的autologin_multi_user.sh，打开的时候有报错**不用管他**
   <img width="845" height="230" alt="image" src="https://github.com/user-attachments/assets/c33511f6-7e43-4272-9bdc-3ec58b845602" />

   然后更改里面的路由器接口名，校园网账号和密码
   <img width="750" height="204" alt="image" src="https://github.com/user-attachments/assets/a3195ff9-670b-4b1f-87f8-80c0dbcae7b2" />
   <img width="625" height="340" alt="image" src="https://github.com/user-attachments/assets/c9d947f2-b071-440b-9ce8-00586325df9b" />

   如果遇到下图这种类似跟ssl有关的报错（**没有这个错误的不用改**）：
   <img width="813" height="141" alt="c7a96631ce66d1f09983f75e1199c6d2" src="https://github.com/user-attachments/assets/d6f7b07d-8c1c-4475-a206-6d6da056bb35" />
   则在脚本的**curl后面添加-k来忽略ssl问题**，如下图所示，改完后别忘了**保存**
   <img width="534" height="155" alt="c8cc3b3deaa5f7cdc3feeac425070632" src="https://github.com/user-attachments/assets/b4ab68ef-70a0-45e0-b86f-03ec3f664d49" />

5. 添加开机启动脚本
   在**系统-启动项-本地启动脚本**中，添加如下代码并保存：
   ```
   # 系统启动后等待20秒
   sleep 20
   
   # 连续执行autologin_multi_user.sh 10次
   for i in 1 2 3 4 5 6 7 8 9 10; do
     bash /root/autologin_multi_user.sh
     sleep 5  # 每次执行间隔5秒
   done
   ```
   #### 注：
   **为什么我不用sh而是bash呢：**因为sh是bash的子集，所以用sh也可以，但是bash可以执行更多的命令，所以建议用bash，有一个**主要原因**就是，**sh不支持网口名字中有点号的，而bash支持**，所以如果网口名字中有点号的话，需要用bash。**有小部分openwrt固件为了空间而没有bash（一般是闪存比较小的路由器会有这种固件）**，请大家合理选用固件

6. 添加计划任务脚本（可不添加）
   本人建议可以给路由器设置一个定时重启，这样就可以每天路由器都会重启一次，然后自动登录
   在**系统-启动项-计划任务**中，添加如下代码并保存：
   ```
   10 5 * * * sleep 30 && touch /etc/banner && reboot
   # 每天5点10分，等待30秒后，自动重启
   # 这只是例子，大家尽量别用一样的时间，以防同时有很多登录校园网的请求，时间自己设置个方便的就行
   ```
7. 断网自动重连脚本（太过暴力暂时不放了）
8. 设置好了之后，路由器只要一开机就会自动登录了，多wan聚合成功效果如下（图中为双WAN聚合）：
   <img width="717" height="282" alt="image" src="https://github.com/user-attachments/assets/3e7345dd-9024-4c2a-b674-fca13ada17ba" />
   <img width="1090" height="520" alt="image" src="https://github.com/user-attachments/assets/178790f3-06fe-4826-a590-48b7ed26142a" />
   <img width="1141" height="665" alt="image" src="https://github.com/user-attachments/assets/cfbef341-0af1-4630-a4bf-fb6444572099" />






   
