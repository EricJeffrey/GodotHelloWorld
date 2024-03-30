# Godot第一人称多人网络游戏

Godot练习项目，效果如图: 

![](./screenshot.png)


# MultiPlayerSpawner/Synchronizer 使用介绍

总结一下使用`MultiPlayerSpawner/Synchronizer`(简称Spawner/Synchronizer，下同)实现多人游戏过程的一些踩坑/经验，实现过程参考了官方的：[高级多人游戏](https://docs.godotengine.org/zh-cn/4.x/tutorials/networking/high_level_multiplayer.html)，[multiplayer-in-godot-4-0-scene-replication](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/)，强烈建议提前阅读一下。

### 简介

1. 服务端生成对象然后由spawner复制
2. Player实例:
   - 一个synchronizer同步事件到server/其它peer
   - 一个synchronizer从服务端同步状态

### 理清复杂的关系

多人游戏通常涉及到*游戏服务器进程*与*多个游戏客户端进程*，因此初学者（比如我）最好提前思考一下游戏中每个实体对象的相对于 服务器与客户端 的关系。以多人游戏里面的玩家为例：

1. 脚本要运行在多个客户端中 - 因为每个客户端的Player场景在 服务器进程/当前客户端进程/其它玩家的客户端进程 里面都有相应的实例，所以需要根据执行进程的不同来进行不同的处理。`multiplayer.get_unique_id()`和`set_multiplayer_authority`可以用来区分当前的执行进程。
2. 玩家的操作或者说状态需要同步给服务器，进而同步给其它客户端，保证所有客户端都能看到玩家的运动。
3. 玩家的位移以及动作要与服务器同步，算是FPS游戏服务器设计的基本需求


### MultiPlayerSpawner

用来将授权端（默认是服务器）创建的对象自动复制到其它的客户端。使用时，通过`add_spawnable_scene()`指定要自动复制的对象；通过检查器中的`Spawn Path`指定对象的生成根路径。

例如，例如使用`add_spawnable_scenen(player)`设置要复制的对象Player，使用game节点作为`Spawn Path`，实现 **服务端创建player对象到场景中时，自动在客户端中的game节点下创建player对象并添加到场景中** 的效果。

### MultiPlayerSynchronizer

用来同步属性到每个客户端上，可以在下方的复制面板中选择需要同步的属性以及同步的频率。例如可以通过选择Player对象的position/rotation等属性同步位置/旋转到服务器与其它客户端，也可以同步导出的变量。

同步是1对多的方式，通过`set_multiplayer_authority`设置同步的授权方，然后需要同步到属性就会从 *授权方* 同步到其它所有的peer。


## 如何使用

下面以一个简单的场景为例介绍具体如何使用Spawner/Synchronizer实现多人游戏：

场景描述：
- main scene: 主场景，`平台 + 几个障碍物 + 摄像机 + 光照 + MultiPlayerSpawner`
  - main.gd   : server/client初始 + 生成Player对象

- Player scene  : 玩家场景，`方块 + 标签 + 摄像机 + InputSync(MultiPlayerSynchronizer) + PosSync(MultiPlayerSynchronizer)`
  - player.gd   : 根据输入更新玩家位置/速度/旋转
  - InputSync.gd: 捕获当前玩家输入 + 同步输入到服务器
  - PosSync.gd  : 从服务器同步玩家位置/旋转等

### 使用方式

以下从进程的角度描述服务器或者一个客户端。`server, client_1, client_2, ...`分别代表服务器、玩家1的客户端进程、玩家2的客户端进程等：

1. **server**添加Player对象到main场景(而不是client)
   - why: MultiPlayerSpawner会从授权端（即服务器）复制Player对象到所有client（即每个client进程的MultiPlayerSpawner会实例化同一个对象并添加到其场景中），因此不能在客户端的逻辑中添加对象

2. 输入由*当前Player*捕获，其它Player实例不处理用户输入
   - why: 由于客户端中可能同时存在自己与其他玩家的多个Player实例，所以只能由**属于自己**的Player实例处理输入，其他玩家的Player实例不用处理输入，可以用`multiplayer.get_unique_id()`区分。

3. *捕获输入* 与 *处理输入* 分开，使用`InputSync`捕获输入并*同步到其它peer*，*根据捕获的输入*处理运动
   - why: 多人游戏的时候，必须把用户的输入同步到服务和其它客户端上，才能保证所有玩家都能互相看到移动/旋转等行为（即当前玩家的行为需要在其它客户机里即时播放），所以需要把这两个行为拆开。

4. 通过`InputSync.set_multiplayer_authority(my_peer_id)`区分执行实体
   - why: 对于一个`Player.InputSync`，只有它的Player身份是当前玩家时才需要处理输入；如果其Player的身份是其它玩家，那么应该跳过对当前玩家输入的捕获，因为这个`InputSync`的属性会从他所隶属的客户端中同步过来。 所以，需要在Player对象初始化时，通过`set_multiplayer_authority`将Player的`authority`设置为所属客户端的peerid，从而在不同的客户端中区分身份。

5. 使用`PosSync`将服务端的执行同步到客户端
   - why: 输入处理发生在服务端才能保证所有客户端看到的一致性

## 小坑
- 使用`resource_local_to_scene` 保证`mesh`是新创建，而不是引用同一个实例
  - 问题现象: `text_mesh`修改其中一个实例的`text`值影响所有其他实例
- jump使用rpc保证服务端能接受到
- 时序问题的小bug: 默认应当让所有的输入由服务端处理，但是本地也可以处理输入，从而在低延迟的时候进行*补偿*，但是这会导致本地收到了状态更新而服务端没收到，造成行为异常
- 为何使用peer_id变量的`setter`函数更新`multiplayer_authority`
  1. 因为本地的对象是由`MultiPlayerSpawner`复制过来的，仅在`peer_id`变量设置之后，客户端才能够设置`multiplayer_authority`
  2. 而`MultiPlayerSpawner`复制实例的时候，变量的setter发生在`_enter_tree`和`_ready`之后
  3. 所以在setter函数中处理是最直观的一种方法
  4. 另: `_process`保证是在变量setter执行完后的，也可以在其中进行一次`multiplayer_authority`

## 总结
能够节省许多对象/属性复制的逻辑，但是文档较为匮乏，导致上手难度略大。

