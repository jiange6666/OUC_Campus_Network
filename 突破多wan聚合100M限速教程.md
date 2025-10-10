#   突破多wan聚合100M限速教程
## 此方法需要走两个上级设备
注意：
首先，插网线是插到交换机上，而宿舍的网，是从墙上的一个ap上面引出来的，如图所示
<img width="912" height="765" alt="7162c85f162093535cf5e04176ba338f" src="https://github.com/user-attachments/assets/0a29b92e-9197-4446-9c93-e00a1ce9fa7e" />
如果是这种情况的话，就很难走两个上级设备，除非你能中继到别的宿舍的网，我宿舍是没法中继到

但是在工位，ap和交换机是分开的，如图所示
![ba4eff686da71a315e83fada69f07675](https://github.com/user-attachments/assets/b88df512-1874-40e5-a98c-61ad3f0c47a4)![6807f1203af1b0a2c973aafdfb83bedf](https://github.com/user-attachments/assets/6cb7f1f3-c2e8-47e8-b894-da00613ac4c6)
这种情况下的话，就可以走两个上级设备的网，从而突破多wan聚合限速100M的限制

## 教程开始
首先在OpenWrt里的无线设置里，添加无线中继，具体教程网上都有，这里不再赘述
，5G和2.4G都可以中继
<img width="1800" height="449" alt="6a873ea9918bcc861f2c146af6b40d2b" src="https://github.com/user-attachments/assets/4d5c15b0-d5a6-4e32-8d25-4993dd8d377d" />
中继成功以后就是这样
<img width="2130" height="1070" alt="9c602ce1d30a6e5d70297816820ce1b1" src="https://github.com/user-attachments/assets/003eb851-4ca2-4528-be95-965fa56b8110" />
注：要确保不要影响路由器本身的无线，如果扫描不到ouc的网，或者没中继成功的话，可以尝试切换信道

-然后你会发现，接口里面会多出两个无线的wan
<img width="1804" height="314" alt="dbdc707290b50df128f303b1416fa6c8" src="https://github.com/user-attachments/assets/7b93badb-cb37-43bb-bed1-7076963902ae" />

-然后把两个无线的wan都添加到负载均衡里(负载均衡网上都有教程，这里不再赘述)

-然后别忘了在登录脚本里添加登录这两个无线wan的账号和密码，自动登录脚本在Readme.md里有教程
<img width="901" height="215" alt="2d2f2e150d96ee192885929a97237d15" src="https://github.com/user-attachments/assets/4f734d2d-09f5-4ff7-9b7c-0919e4d425b1" />
最后保存并应用，然后重启路由器，就实现了多wan聚合突破100M的限制

## 效果：
多wan聚合本身有一点损耗，我这是2个有线加2个无线聚合的效果，就相当于4个wan聚合，校园网一个端口限速40M，4个wan聚合能达到这140多M已经非常不错了
<img width="901" height="215" alt="2d2f2e150d96ee192885929a97237d15" src="https://github.com/user-attachments/assets/b9bd86cb-0075-44d8-b0ae-a3de23e0c0f8" />
<img width="616" height="233" alt="9bfc0f2ea5e06cd15abef70ce5ec45c4" src="https://github.com/user-attachments/assets/775b490d-4fb4-454e-a3d3-3da2ad6c4bd6" />
<img width="611" height="714" alt="ce93d9a72ad2f859a7632b0de6c07e83" src="https://github.com/user-attachments/assets/0b96bfb1-e54b-4baf-8d89-fdbdabc94cc6" />


