const rooms = new Map();
const ROOM_VERSION = 3;

function createRoom() {
  const rows = [
    ["周报素材整理", "进行中", "下午再看一下"],
    ["页面间距调整", "已完成", "视觉更紧凑"],
    ["下次会议准备", "待处理", "先列三个要点"],
    ["首页数据核对", "完成", ""],
    ["用户反馈整理", "进行中", "等截图"],
    ["接口响应检查", "", ""],
    ["移动端布局复核", "进行中", "横屏也看一下，尤其是表格这里"],
    ["文案版本确认", "已完成", "已同步"],
    ["图片资源归档", "待处理", "放共享目录"],
    ["登录流程测试", "已完成", "测试账号通过"],
    ["搜索体验优化", "进行中", "补空状态提示"],
    ["表格字段确认", "已完成", ""],
    ["演示数据准备", "进行中", "本周样例还差一些"],
    ["权限边界检查", "待处理", "共享目录需要复核"],
    ["服务日志查看", "完成", "暂无异常请求"],
    ["发布说明草拟", "进行中", "周五前？"],
    ["数据库连接验证", "已完成", ""],
    ["收藏卡片检查", "进行中", "长标题要截断"],
    ["目录树交互复核", "待处理", "关注选中状态"],
    ["浏览器兼容测试", "进行中", "补测 Safari / Edge"],
    ["备份文件清理", "已完成", "保留最近两份"],
    ["工作流文档更新", "待处理", ""],
    ["接口错误提示统一", "进行中", "统一 401 文案"],
    ["随机推荐复核", "已完成", "递归目录正常"],
    ["文件传输测试", "进行中", "100 MB 文件还没测"],
    ["协作页面初始化", "已完成", "加入临时工作表"],
    ["在线编辑冲突检查", "待处理", "准备两端测试"],
    ["用户名显示确认", "进行中", ""],
    ["导航入口整理", "已完成", "保留必要图标"],
    ["生产配置复核", "待处理", "确认数据库网络"],
    ["本周事项收尾", "进行中", "下午统一检查"],
    ["临时记录", "", "先放这里"],
    ["会议室预定", "已完成", "周四 15:00"],
    ["资料链接补充", "待处理", ""],
    ["旧页面截图", "已完成", "不用删，留着对比"],
    ["跟进设计反馈", "进行中", "明天再确认一轮"],
    ["报销单", "", ""]
  ];
  return {
    version: ROOM_VERSION,
    topics: [{
      id: "topic-1",
      name: "今日记录",
      cells: [["MES添加新测试站的流程"], ["No", "系统", "步骤", "详细信息", "RD", "时间", "结果"], ...rows.map((row, index) => [index + 1, "BOP", row[0], row[2], "", "", row[1]])],
      cellAuthors: {},
      messages: []
    }],
    clients: new Set()
  };
}

function getRoom(roomId = "main") {
  if (!rooms.has(roomId) || rooms.get(roomId).version !== ROOM_VERSION) {
    rooms.set(roomId, createRoom());
  }
  return rooms.get(roomId);
}

function broadcast(room, message, except) {
  const payload = JSON.stringify(message);
  room.clients.forEach((client) => {
    if (client !== except && client.readyState === 1) client.send(payload);
  });
}

function removeClient(roomId, client) {
  const room = rooms.get(roomId);
  if (!room) return;
  room.clients.delete(client);
  if (!room.clients.size) rooms.delete(roomId);
}

module.exports = { getRoom, broadcast, removeClient };
