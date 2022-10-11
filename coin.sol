// Version 0.5  
//https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/utils
pragma solidity ^0.8.0;
import "./erc20.sol";
contract ECoin 
{
mapping (address => int) balances;
address owner;
address pile;
bool flag;
uint counter;

struct record 
{
address from;
address to;
int value;
string comment;
} 
mapping (uint => record) records;

function eCoin() public
{
owner = msg.sender;
balances[owner] = 1000000000;
flag = true;
counter = 1;
}

function tsRecords(uint idx) private returns(address from, address to, int val, string memory comm) 
{
from = records[idx].from;
to = records[idx].to;
val = records[idx].value;
comm = records[idx].comment;
}

function transfer(address from, address to, int value, string memory comment) public
{
records[counter].from = from;
records[counter].to = to;
records[counter].value = value; 
records[counter].comment = comment;
counter++;
}


function exeOnce(address addr) public
{
if (flag)
{
pile = addr;
}
//flag = false; 测试时注释
}

function getBalance(address addr)public returns(int) 
{
return balances[addr];
}
function getOwner()public returns(address) 
{
return owner;
}

function verify()public returns(address a, address b, address c)
{
a = msg.sender;
b = pile;
c = owner;
}

function verify1()public returns(address)
{
return msg.sender;
}

function prepay(address client, int preFee)public returns(bool success) 
{ 
if (msg.sender != pile)
{
return false;
}

balances[client] -= preFee;
balances[owner] += preFee;
transfer(client, address(this), preFee, "prepay");
return true;
}
function confirm(address client, address driver, int preFee, int finalFee)public returns(bool success) 
{ 
if (msg.sender != pile)
{
return false;
}

int remain = preFee - finalFee;
balances[owner] -= preFee;
balances[client] += remain;
balances[driver] += finalFee;
transfer(address(this), client, remain, "remain fee");
transfer(address(this), driver, finalFee, "final fee");
return true;
}

function penalty(address from, address to, int amount)public returns(bool)//罚金
{
if (msg.sender != pile)
{
return false;
}

balances[from] -= amount;
balances[to] += amount;
}

function recharge(address addr, int amount)public returns(bool)//充电
{
if (msg.sender != owner)
{
return false;
}
if (balances[owner] < amount)
{
return false;
}
balances[addr] += amount;
balances[owner] -= amount;
return true;
}
}




//只允许车主修改，但允许任何人查询
contract Owner
{
struct data
{
address name;
string info0;
string info1;
string info2;
}
mapping (address => data) owners;

function modifyInfo(string memory info0, string memory info1, string memory info2)public returns(bool)//改变当前三类信息（具体我们再定）
{
owners[msg.sender].name = msg.sender;
owners[msg.sender].info0 = info0;
owners[msg.sender].info1 = info1;
owners[msg.sender].info2 = info2;
}

function getInfo()public returns(string memory info0, string memory info1, string memory info2)//读取本人信息
{
info0 = owners[msg.sender].info0;
info1 = owners[msg.sender].info1;
info2 = owners[msg.sender].info2;
}

function getInfoWithAddress(address owner)public returns(string memory info0, string memory info1, string memory info2)//查询他人信息
{
info0 = owners[owner].info0;
info1 = owners[owner].info1;
info2 = owners[owner].info2;
}
}


contract ChPile 
{

ECoin ecoin ;
Owner pass ;
mapping (address => uint) driverToOrder; //每个车主对应到某个订单
mapping (address => uint) pileToOrder; //每充电桩对应到某个订单
uint counterOrderIndex; //下一个空的订单序号
//订单需要的信息
struct Order
{
uint id; //订单编号
address driver; //司机地址
address pile; //充电桩地址
int s_x; //起点经度
int s_y; //起点纬度
int d_x; //终点经度
int d_y; //终点纬度
string sName; //起点地名
string dName; //终点地名
int distance; //起终点直线距离
int preFee; //预付款额
int actFee; //实际款额
int actFeeTime;
uint startTime; //UNIX标准时间
uint pickTime;
uint endTime; //UNIX标准时间
int state; //订单状态 1待分配 2已被抢 3订单完成 4订单终止
string passInfo; //乘客个人信息，utf8
string pileInfo0; //司机个人信息，utf8
string pileInfo1;
string pileInfo2;
}
mapping (uint => Order) orders;

mapping (address => uint) pileIndexs; //给每个充电桩分配一个内部的序号
uint counterPileIndex; //下一个空闲的充电桩序号（当前充电桩数量+1）
struct Pile
{
int cor_x; //经度
int cor_y; //纬度
bool state; //true 表示接单中 false 表示休息中
address name; //电桩地址
string info0;
string info1;
string info2;
uint counterOrder; //充电桩当前可接订单数
uint[8] orderPool; //充电桩可接订单池
int last_x; //上一次经度（可调整为功率、运作时间）
int last_y; //上一次纬度
}
mapping (uint => Pile) piles; //使用序号去寻找司机的信息

mapping (address => uint) driverStates; //车主状态 0 1 2 3 4
mapping (address => uint) pileStates; //充电桩状态 0 1 2 3

mapping (address => uint[5]) driverNearPiles;

struct Judgement
{
int total; //总评价数
int avgScore; //平均分
mapping (int => int) score; //单次分数
mapping (int => string) comment; //单次评价
}

//mapping (address => Judgement) passengerJudgements;
mapping (address => Judgement) pileJudgements;

struct driverPosition
{
int x;
int y;
}
mapping (address => driverPosition) passPos;

//里程单价 0.01币：0.1米 => 1km = 100块
int unitPrice = 1;
int unitPriceTime = 1;

int penaltyPrice = 500;

function piling() public
{
counterPileIndex = 1;
counterOrderIndex = 1;
}

function sqrt(int x) private returns (int)
{ 
if(x < 0)
x = - x;
int z = (x + 1) / 2;
int y = x;
while (z < y) 
{
y = z;
z = (x / z + z) / 2;
}
return y;
}

//不会因为乘方而溢出，若距离超过了最大的表示范围，则返回值是-1
// function calculateDistance(int x0, int x1, int y0, int y1) private returns(int)
// {
// int tempX = x0 - x1;
// int tempY = y0 - y1;
// int maxDiff = 32700;
// int mult = 1;

// while(tempX > maxDiff || tempX < -maxDiff || tempY > maxDiff || tempY < - maxDiff)
// {
// x1 = (x0 + x1) / 2;
// y1 = (y0 + y1) / 2;
// mult *= 2;
// tempX = x0 - x1;
// tempY = y0 - y1;
// if (mult <= 0)
// {
// return -1;
// }
// }

// return mult * sqrt(tempX*tempX + tempY*tempY);
// }

function calculateDistance(int x0, int x1, int y0, int y1) private returns(int)
{
int tempX = x0 - x1;
int tempY = y0 - y1;
return sqrt(tempX*tempX + tempY*tempY);
}

function pileSelction(int x, int y, uint orderIndex) private returns(bool)
{
uint i;
uint j;
int threshold = 500000; //阀值，当距离小于该值之后则派单，数值可调整
int temp;
uint maxOrder = 8; //充电桩可响应的最大订单数量
bool flag = false;
for (i=1; i<counterPileIndex; ++i)
{
if (piles[i].state && pileStates[piles[i].name] == 0) //
{
temp = calculateDistance(x, piles[i].cor_x, y, piles[i].cor_y);
if (temp < threshold)
{
//找到订单池中的空位
for(j=0; j<maxOrder; ++j)
{
if(orders[piles[i].orderPool[j]].state != 1)
{
flag = true;
piles[i].orderPool[j] = orderIndex;
break;
}
}
}
}
}
return flag;
}

function calculatePreFee(int s_x, int s_y, int d_x, int d_y) private returns(int)
{
int tempX = s_x - d_x;
int tempY = s_y - d_y;
if (tempX < 0)
{
tempX = -tempX;
}
if (tempY < 0)
{
tempY = -tempY;
}
return ((tempX + tempY) * unitPrice) / 2 * 3 / 100;
//return unitPrice * calculateDistance(s_x, d_x, s_y, d_y);
}

function driverSubmitOrder(int s_x, int s_y, int d_x, int d_y, uint time, string memory passInfo, string memory sName, string memory dName)public returns(uint)
{
if(ecoin.getBalance(msg.sender) < 0) //车主账户余额必须是正数
{
return 0;
}
if(driverStates[msg.sender] != 0) //车主必须处于挂起状态充电桩才能相应派单
{
return 0;
}
if (counterPileIndex <= 1) //没有空闲充电桩
{
return 0;
}

//创建新的订单
driverToOrder[msg.sender] = counterOrderIndex;
orders[counterOrderIndex].id = counterOrderIndex;
orders[counterOrderIndex].driver = msg.sender;
orders[counterOrderIndex].pile = address(0x0);
orders[counterOrderIndex].s_x = s_x;
orders[counterOrderIndex].s_y = s_y;
orders[counterOrderIndex].d_x = d_x;
orders[counterOrderIndex].d_y = d_y;
orders[counterOrderIndex].distance = 0;//calculateDistance(s_x, d_x, s_y, d_y);
orders[counterOrderIndex].preFee = penaltyPrice + calculatePreFee(s_x, s_y, d_x, d_y);
orders[counterOrderIndex].actFee = 0;
orders[counterOrderIndex].actFeeTime = 0;
orders[counterOrderIndex].startTime = time;
orders[counterOrderIndex].state = 1;
orders[counterOrderIndex].passInfo = passInfo;
orders[counterOrderIndex].sName = sName;
orders[counterOrderIndex].dName = dName;
counterOrderIndex++;
pileStates[msg.sender] = 1; //乘客订单分配中

if(!pileSelction(s_x, s_y, counterOrderIndex-1))
{
orders[counterOrderIndex-1].state = 4;
pileStates[msg.sender] = 0;
return 0;
}
return counterOrderIndex-1;
}

function pileCompetOrder(uint orderIndex)public returns(bool)
{ 
if(pileIndexs[msg.sender] == 0) //充电桩没有注册
{
return false;
}
if(driverStates[msg.sender] != 0) //充电桩不在挂起状态
{
return false;
}
if(orders[orderIndex].state != 1) //派单失败
{
return false;
}
orders[orderIndex].state = 2;
orders[orderIndex].pile = msg.sender;
//orders[orderIndex].drivInfo = drivers[driverIndexs[msg.sender]].info;
orders[orderIndex].pileInfo0 = piles[pileIndexs[msg.sender]].info0;
orders[orderIndex].pileInfo1 = piles[pileIndexs[msg.sender]].info1;
orders[orderIndex].pileInfo2 = piles[pileIndexs[msg.sender]].info2;

//passengerLinks[orders[orderIndex].passenger] = msg.sender;
//driverLinks[msg.sender] = orders[orderIndex].passenger;
driverStates[orders[orderIndex].driver] = 2; //车主待付款
pileStates[msg.sender] = 1; //充电桩已接单
pileToOrder[msg.sender] = orderIndex;

//初始化司机上一次位置（调整为充电状态）
piles[pileIndexs[msg.sender]].last_x = orders[orderIndex].s_x; 
piles[pileIndexs[msg.sender]].last_y = orders[orderIndex].s_y;
return true;
} 

function driverPrepayFee()public returns(bool)
{
uint orderIndex = driverToOrder[msg.sender];
address pile = orders[orderIndex].pile;

//车主不是待付款 或者订单不是已被抢
if (driverStates[msg.sender] != 2 || orders[orderIndex].state != 2)
{
return false;
}

//付款过程，确定款项已经进入合约账户
if (ecoin.prepay(msg.sender, orders[orderIndex].preFee))
{
driverStates[msg.sender] = 3;
pileStates[pile] = 2;
return true;
}
//下面是支付失败的逻辑，或者是乘客取消订单的逻辑，目前没有处理，待加入，例如订单状态的改变等
else
{
//....
orders[orderIndex].state = 4;
driverStates[msg.sender] = 0;
pileStates[pile] = 0;
return false;
}
}

function pilecalldriver(int x, int y, uint time)public returns(bool)
{
uint orderIndex = pileToOrder[msg.sender];
address driver = orders[orderIndex].driver;

if (pileStates[msg.sender] != 2 || driverStates[driver] != 3 || orders[orderIndex].state != 2)
{
return false;
}

int passX = passPos[driver].x;
int passY = passPos[driver].y;
int threshold = 2000;
if (calculateDistance(x, passX, y, passY) > threshold)
{
return false;
}

piles[pileIndexs[msg.sender]].last_x = x;
piles[pileIndexs[msg.sender]].last_y = y;
orders[orderIndex].pickTime = time;

driverStates[driver] = 4;
pileStates[msg.sender] = 3;
return true;
}
/*(给出充电桩收费函数)
function pileCalculateActFee(int cur_x, int cur_y) returns(int)
{
uint orderIndex = pileToOrder[msg.sender];
uint pileindex = pileIndexs[msg.sender];
int distance;
address passenger = orders[orderIndex].passenger;

if (driverStates[msg.sender] != 3 || passengerStates[passenger] != 4 || orders[orderIndex].state != 2)
{
return 0;
}
distance = calculateDistance(cur_x, drivers[driverindex].last_x, cur_y, drivers[driverindex].last_y);
orders[orderIndex].distance += distance;
orders[orderIndex].actFee += distance * unitPrice / 100;
drivers[driverindex].cor_x = cur_x;
drivers[driverindex].cor_y = cur_y;
drivers[driverindex].last_x = cur_x;
drivers[driverindex].last_y = cur_y;
return orders[orderIndex].actFee;
}
*/
function driverFinishOrder(uint time)public returns(bool)
{
uint orderIndex = driverToOrder[msg.sender];
address driver = orders[orderIndex].driver;
//充电桩不是使用中，订单不是已被抢
if (pileStates[msg.sender] != 3 || driverStates[driver] != 4 || orders[orderIndex].state != 2)
{
return false;
}
orders[orderIndex].actFeeTime = (int)(time - orders[orderIndex].pickTime) * unitPriceTime;
int preFee = orders[orderIndex].preFee;
int finalFee = orders[orderIndex].actFee + orders[orderIndex].actFeeTime;
if (finalFee > preFee)
{
finalFee = preFee;
orders[orderIndex].actFee = finalFee - orders[orderIndex].actFeeTime;
}

//支付
if (ecoin.confirm(driver, msg.sender, preFee, finalFee))
{
orders[orderIndex].state = 3;
orders[orderIndex].endTime = time;
driverStates[driver] = 0;
pileStates[msg.sender] = 0;
return true;
}
//同上，若支付失败要怎么办
else
{
//....
driverStates[driver] = 0;
pileStates[msg.sender] = 0;
orders[orderIndex].state = 4;
return false;
}
}

function getPileState()public returns(uint)
{
return pileStates[msg.sender];
}

function getDriverState()public returns(uint)
{
return driverStates[msg.sender];
}

function getpileRegiterState()public returns(bool)
{
if (pileIndexs[msg.sender] > 0)
{
return true;
}
else
{
return false;
}
}

function newpileRegister(string memory info0, string memory info1, string memory info2)public returns(uint)
{
if (pileIndexs[msg.sender] > 0)//已经注册
{
return pileIndexs[msg.sender];
}
pileIndexs[msg.sender] = counterPileIndex;
piles[counterPileIndex].state = false;
piles[counterPileIndex].name = msg.sender;
piles[counterPileIndex].cor_x = 0x7FFFFFFF;
piles[counterPileIndex].cor_y = 0x7FFFFFFF;
piles[counterPileIndex].info0 = info0;
piles[counterPileIndex].info1 = info1;
piles[counterPileIndex].info2 = info2;
piles[counterPileIndex].counterOrder = 0;
pileStates[msg.sender] = 0;
counterPileIndex++;
return counterPileIndex - 1;
}

function pileUpdatePos(int x, int y, bool state)public returns(bool)
{
uint tempIndex = pileIndexs[msg.sender];
if (tempIndex == 0)
{
return false;
}
else
{
piles[tempIndex].cor_x = x;
piles[tempIndex].cor_y = y;
piles[tempIndex].state = state;//改一下，改成储存电量之类的状态
return true;
}
}

function getpilerOrderPool()public returns(uint[8] memory)//导出订单池
{
uint pileIndex = pileIndexs[msg.sender];
uint i;
for (i=0; i<8; ++i)
{
uint orderIndex = piles[pileIndex].orderPool[i];
if (orderIndex != 0 && orders[orderIndex].state != 1)
{
piles[pileIndex].orderPool[i] = 0;
}
}
return piles[pileIndex].orderPool;
}


function getOrderID(bool isdriver)public returns(uint)
{
uint orderIndex;
if(isdriver)
{
orderIndex = driverToOrder[msg.sender];
}
else
{
orderIndex = pileToOrder[msg.sender];
}
return orderIndex;
}

function getOrderInfo0(uint orderIndex)public returns(uint id, address driver, int s_x, int s_y, int d_x, int d_y, int distance, int preFee, uint startTime, string memory passInfo) 
{
id = orders[orderIndex].id;
driver = orders[orderIndex].driver;
s_x = orders[orderIndex].s_x;
s_y = orders[orderIndex].s_y;
d_x = orders[orderIndex].d_x;
d_y = orders[orderIndex].d_y;
distance = orders[orderIndex].distance;
preFee = orders[orderIndex].preFee;
startTime = orders[orderIndex].startTime;
passInfo = orders[orderIndex].passInfo;
}

function getOrderInfo1(uint orderIndex)public returns(address pile, int actFee, int actFeeTime, uint pickTime, uint endTime, int state)
{
pile = orders[orderIndex].pile;
actFee = orders[orderIndex].actFee;
actFeeTime = orders[orderIndex].actFeeTime;
pickTime = orders[orderIndex].pickTime;
endTime = orders[orderIndex].endTime;
state = orders[orderIndex].state;//接单时间可调整为冲上电的时间
}

//车主调用
//等待充电桩接客界面轮循调用
function getOrderStateAndpilePos(uint orderIndex)public returns(int state, int x, int y) 
{
uint pileIndex;
address pile = orders[driverToOrder[msg.sender]].pile;
pileIndex = pileIndexs[pile];
state = orders[orderIndex].state;
x = piles[pileIndex].cor_x;
y = piles[pileIndex].cor_y;
}

function getPassStateAndDriPos()public returns(uint state, int x, int y)
{
uint pileIndex;
address pile = orders[driverToOrder[msg.sender]].pile;
pileIndex = pileIndexs[pile];
state = driverStates[msg.sender];
x = piles[pileIndex].cor_x;
y = piles[pileIndex].cor_y;
}

function getOrderState(uint orderIndex)public returns(int) 
{
return orders[orderIndex].state;
}

function getOrderPreFee(uint orderIndex)public returns(int) 
{
return orders[orderIndex].preFee;
}

function getOrderActFee(uint orderIndex)public returns(int) 
{
return orders[orderIndex].actFee;
}

function getOrderDisAndActFee(uint orderIndex)public returns(int distance, int actFeeD, int actFeeT, uint duration)
{
distance = orders[orderIndex].distance;
actFeeD = orders[orderIndex].actFee;
actFeeT = orders[orderIndex].actFeeTime;
duration = orders[orderIndex].endTime - orders[orderIndex].startTime;
}

function getOrderPassInfo(uint orderIndex)public returns(string memory)
{
return orders[orderIndex].passInfo;
}

function getOrderPileInfo(uint orderIndex)public returns(string memory pileInfo0, string memory pileInfo1, string memory pileInfo2)
{
pileInfo0 = orders[orderIndex].pileInfo0;
pileInfo1 = orders[orderIndex].pileInfo1;
pileInfo2 = orders[orderIndex].pileInfo2;
}

function getOrderFeeStimeAndPlaceName(uint orderIndex)public returns(int fee, uint time, string memory sName, string memory dName)
{
fee = orders[orderIndex].preFee;
time = orders[orderIndex].startTime;
sName = orders[orderIndex].sName;
dName = orders[orderIndex].dName;
}

function getOrderPlaceName(uint orderIndex)public returns(string memory sName, string memory dName)
{
sName = orders[orderIndex].sName;
dName = orders[orderIndex].dName;
}

function getNearpiles(int x, int y, int threshold)public returns(uint[5] memory)
{
uint maxNear = 5;
uint i;
uint j = 0;
for (i=0; i<5; ++i)
{
driverNearPiles[msg.sender][i] = 0;
}
for (i=1; i<counterPileIndex; ++i)
{
if (piles[i].state && pileStates[piles[i].name] == 0)
{
if (calculateDistance(x, piles[i].cor_x, y, piles[i].cor_y) < threshold)
{
driverNearPiles[msg.sender][j++] = i;
}
}
else
{
continue;
}
if(j >= maxNear)
{
break;
}
}
return driverNearPiles[msg.sender];
}

function getPileInfo(bool isdriver)public returns(int x, int y, address name, string memory info0, string memory info1, string memory info2)
{
uint pileIndex;
address pile;
if (isdriver)
{

pile = orders[driverToOrder[msg.sender]].pile;
}
else 
{
pile = msg.sender;
}
pileIndex = pileIndexs[pile];

x = piles[pileIndex].cor_x;
y = piles[pileIndex].cor_y;
name = piles[pileIndex].name;
info0 = piles[pileIndex].info0;
info1 = piles[pileIndex].info1;
info2 = piles[pileIndex].info2;
}

// function getDriverPos() returns(int x, int y) //乘客调用
// {
// uint driverIndex;
// address driver;

// driver = orders[passengerToOrder[msg.sender]].driver;
// driverIndex = driverIndexs[driver];

// x = drivers[driverIndex].cor_x;
// y = drivers[driverIndex].cor_y;
// }

function pileChangeInfo(string memory newInfo0, string memory newInfo1, string memory newInfo2)public returns(bool)
{
if (pileIndexs[msg.sender] == 0)
{
return false;
}
piles[pileIndexs[msg.sender]].info0 = newInfo0;
piles[pileIndexs[msg.sender]].info1 = newInfo1;
piles[pileIndexs[msg.sender]].info2 = newInfo2;
return true;
}

function driverCancelOrder(bool isPenalty)public returns(bool) 
{
uint orderIndex = driverToOrder[msg.sender];
address pile = orders[orderIndex].pile;

//车主在充电桩接单前取消订单，没有任何惩罚（惩罚函数配置）
if (driverStates[msg.sender] == 1 && orders[orderIndex].state == 1)
{
driverStates[msg.sender] = 0;
orders[orderIndex].state = 4;
return true;
}

//车主在充电桩接单后、自己预付款前取消订单，没有惩罚（惩罚函数配置）
if (driverStates[msg.sender] == 2 && pileStates[pile] == 1 && orders[orderIndex].state == 2)
{
driverStates[msg.sender] = 0;
pileStates[pile] = 0;
orders[orderIndex].state = 4;
return true;
}

//乘客在预付款后、等待司机接客时取消订单
if (driverStates[msg.sender] == 3 && pileStates[pile] == 2 && orders[orderIndex].state == 2)
{
//退还预付款
if (!ecoin.confirm(msg.sender, pile, orders[orderIndex].preFee, 0))
{
return false;
}
//违约金
if (isPenalty)
{
ecoin.penalty(msg.sender, pile, penaltyPrice);
}
driverStates[msg.sender] = 0;
pileStates[pile] = 0;
orders[orderIndex].state = 4;
return true;
}

return false;
}

function pileCancelOrder()public returns(bool) //充电桩在特殊情况取消订单
{
uint orderIndex = driverToOrder[msg.sender];
address driver = orders[orderIndex].driver;

if (pileStates[msg.sender] == 1 && driverStates[driver] == 2 && orders[orderIndex].state == 2)
{
driverStates[driver] = 0;
pileStates[msg.sender] = 0;
orders[orderIndex].state = 4;
return true;
}

if (pileStates[msg.sender] == 2 && driverStates[driver] == 3 && orders[orderIndex].state == 2)
{
//退还预付款
if (!ecoin.confirm(driver, msg.sender, orders[orderIndex].preFee, 0))
{
return false;
}
ecoin.penalty(msg.sender, driver, penaltyPrice);
driverStates[driver] = 0;
pileStates[msg.sender] = 0;
orders[orderIndex].state = 4;
return true;
}

return false;
}

function pileJudge(int score, string memory comment)public returns(bool)//车主使用后评价
{
uint orderIndex = driverToOrder[msg.sender];
address pile = orders[orderIndex].pile;
int total = pileJudgements[pile].total;
if (orderIndex == 0)
{
return false;
}

driverToOrder[msg.sender] = 0;//分数导致后果制定
if (score > 5000)
score = 5000;
if (score < 0)
score = 0;
pileJudgements[pile].avgScore = (pileJudgements[pile].avgScore * total + score) / (total + 1);
pileJudgements[pile].total += 1;
total++;
pileJudgements[pile].score[total] = score;
pileJudgements[pile].comment[total] = comment;
return true;
}

function getJudge(bool isDriver)public returns(int avgScore, int total)
{
address pile;
if (isDriver)
{
uint orderIndex =driverToOrder[msg.sender];
pile = orders[orderIndex].pile;
}
else 
{
pile = msg.sender;
}
avgScore = pileJudgements[pile].avgScore;
total = pileJudgements[pile].total;
}


function getAccountBalance()public returns(int)
{
return ecoin.getBalance(msg.sender);
}

function verify()public returns(address)
{
return ecoin.verify1();
}

function updateDriverPos(int x, int y) public
{
passPos[msg.sender].x = x;
passPos[msg.sender].y = y;
}

function tsTotalNumOfOrder()public returns(uint)
{
return counterOrderIndex - 1;
}

function tsTotalNumOfPile()public returns(uint)
{
return counterPileIndex - 1;
}

function tsPileInfoIdx(uint pileIndex)public returns(int x, int y, address name, string memory info0, string memory info1, string memory info2)
{
x = piles[pileIndex].cor_x;
y = piles[pileIndex].cor_y;
name = piles[pileIndex].name;
info0 = piles[pileIndex].info0;
info1 = piles[pileIndex].info1;
info2 = piles[pileIndex].info2;
}

function tsPileInfoAddr(address addr)public returns(int x, int y, address name, string memory info0, string memory info1, string memory info2)
{
uint pileIndex;
address pile = addr;

pileIndex = pileIndexs[pile];
x = piles[pileIndex].cor_x;
y = piles[pileIndex].cor_y;
name = piles[pileIndex].name;
info0 = piles[pileIndex].info0;
info1 = piles[pileIndex].info1;
info2 = piles[pileIndex].info2;
}
}

//////////////////////////////
/////////////////////////////
//
//
//
//
//
//
//
//
//可以作为电网公司集合的合约·？？
contract CompaniesContract {
string[] CompanyNamesList;
address[] CompanyFounderList;
ECoin ecoin;
constructor() {}

struct CompanyDetail {
string Name;
int totalecoin;//获取电权上限
int availableecoin;//目前可获得数额
int ecoinPrice;
bool isRegistered;
bool isApproved;
}

mapping(address => CompanyDetail) public CompaniesDetails;

function getCompanyDetails(address _Cpnyaddr)
public
view
returns (CompanyDetail memory)
{
return CompaniesDetails[_Cpnyaddr];
}

function getAllCompanies() public view returns (address[] memory) {
return CompanyFounderList;
}

function isApproved(address _CpnyAddr) public view returns (bool) {
if (CompaniesDetails[_CpnyAddr].isApproved == true) {
return true;
} else {
return false;
}
}

function isRegistered(address _CpnyAddr) public view returns (bool) {
if (CompaniesDetails[_CpnyAddr].isRegistered == true) {
return true;
} else {
return false;
}
}

function _requestRegisterMyCompany(
address _msgSender,
string memory _Name,
int _totalecoin,
int _ecoinPrice
) public payable {
require(
CompaniesDetails[_msgSender].isRegistered == false,
"Company Already Registered on this Account"
);

for (uint256 index = 0; index < CompanyNamesList.length; index++) {
require(
keccak256(bytes(CompanyNamesList[index])) !=
keccak256(bytes(_Name)),
"Company Name Already Exists"
);
}

//adding to companydetails array
CompaniesDetails[_msgSender] = CompanyDetail({
Name: _Name,
totalecoin: _totalecoin,
availableecoin: _totalecoin,
ecoinPrice: _ecoinPrice,
isRegistered: true,
isApproved: false
});

//adding to list
CompanyNamesList.push(_Name);
CompanyFounderList.push(_msgSender);
}

function _approveCompany(address _CpnyAddr) external {
require(
CompaniesDetails[_CpnyAddr].isRegistered == true,
"No such company registration request found"
);
require(
CompaniesDetails[_CpnyAddr].isApproved == true,
"Company is already approved"
);
CompaniesDetails[_CpnyAddr].isApproved = true;
}

function getEcoinPrice(address _CpnyAddr) public view returns (int) {
require(
isApproved(_CpnyAddr) == true,
"Company is not approved or registered"
);
return CompaniesDetails[_CpnyAddr].ecoinPrice;
}

function reducedecoin(address _CpnyAddr, int numberofecoin)
public
payable
{
require(isApproved(_CpnyAddr) == true, "Company not approved");
require(
CompaniesDetails[_CpnyAddr].availableecoin >= numberofecoin,
"No more ecoins"
);

CompaniesDetails[_CpnyAddr].availableecoin -= numberofecoin;
}

//approve company implmented in share market
}
//////////////////////////////
/////////////////////////////
//
//
//
//
//
//
//
//
//可以作为政府管理集合的合约·？？
contract Governable {
constructor(string memory _Name) {
address Owner = msg.sender;
Governers[Owner] = Governer({
Name: _Name,
Governer_ID: Governer_ID_Seed
});
GovernerAddresses.push(Owner);

emit GovernerAdded(Owner, Governer_ID_Seed, Owner);
Governer_ID_Seed += 1;
}

event GovernerAdded(
address indexed newGoverner,
uint256 Governer_ID,
address indexed Addedby
);

uint256 private Governer_ID_Seed = 1;
address[] public GovernerAddresses;

struct Governer {
string Name;
uint256 Governer_ID;
}

mapping(address => Governer) Governers;

modifier onlyGoverner() {
require(
Governers[msg.sender].Governer_ID != 0,
"Governable : caller must be a member of the Governers"
);
_;
}

function getGoverners() public view returns (address[] memory) {
return GovernerAddresses;
}

function addGoverner(address _newGoverner, string memory _Name)
public
payable
onlyGoverner
{
address Owner = msg.sender;

require(
Governers[_newGoverner].Governer_ID != 0,
"governer already added"
);

Governers[_newGoverner] = Governer({
Name: _Name,
Governer_ID: Governer_ID_Seed
});
GovernerAddresses.push(_newGoverner);
emit GovernerAdded(_newGoverner, Governer_ID_Seed, Owner);
Governer_ID_Seed += 1;
}

function isGoverner(address _addr) public view returns (bool) {
if (Governers[_addr].Governer_ID != 0) {
return true;
}
return false;
}
}

//////////////////////////////
/////////////////////////////
//
//
//
//
//
//
//
//

contract StockToken is ERC20 {
constructor(uint256 _initialsupply) ERC20("StockToken", "STT") {
_mint(address(this), _initialsupply);
}

uint256 public conversionRate = 1500;

event toppedUp(address indexed Receiver, uint256 Amount);

function TopUP() public payable {
uint256 payment = msg.value;
require(payment > 0, "You need to send some ether");
uint256 available = this.balanceOf(address(this));
uint256 needed = payment * conversionRate;

require(
needed < (available * 10**18),
"Not enough tokens available for transfer at the moment"
);
_transfer(address(this), msg.sender, needed / (10**18));
emit toppedUp(msg.sender, payment);
}
}
/////////////////////////////
/////////////////////////////
//
//
//
//
//
//
//
//
contract ShareMarket is Governable("Contract Deployer"), ECoin,StockToken(1000000) {//公司之间交易
    enum OrderSide {BUY, SELL}
    enum OrderType {LIMIT, MARKET}
    enum OrderAvailability {OPEN, FOK, IOC}
event companyRegistrationRequested(address indexed Owner, string Name);
event companyRegistrationApproved(
address indexed Governer,
address indexed CompanyAccount
);
event EcoinPostForSale(
address seller,
address company,
int numofecoin,
uint256 Price,
OrderAvailability orderAvailability
);
event EcoinPurchase(
address buyer,
address seller,
address company,
int numofEcoin,
uint256 cost,
OrderAvailability orderAvailability
);
ECoin ecoin;
uint256 CompanyCreationCost = 450; //STT
uint256 GovernerApprovalFee = 50; //STT
uint256 PostEcoinFee = 5; //STT
uint256 removeStockFromMarket = 1; //STT

struct SalePost {
address Company;
address Seller;
int numberofecoin;
uint256 price;
}

mapping(uint256 => SalePost) SalePosts;
uint256 private SaleID = 0;

function getNewSaleID() internal returns (uint256) {
if (uint256(SaleID) >= 99999999999) {
SaleID = 0;
}
SaleID++;
return SaleID;
}

//mapping(address => mapping(address => uint256)) ShareDetailsMap;

CompaniesContract private _Companies;

constructor() {
_Companies = new CompaniesContract();
}

//res = await Contract.methods.requestRegisterMyCompany("Acme",100,1234).send({from:accounts[2],'gas':'1000000'})
function requestRegisterMyCompany(
string memory _Name,
int _totalecoin,
int _ecoinPrice
) public payable {
//require(msg.value >= 0);
_Companies._requestRegisterMyCompany(
msg.sender,
_Name,
_totalecoin,
_ecoinPrice
);
emit companyRegistrationRequested(msg.sender, _Name);
}

function approveCompany(address _CpnyAddr) public payable onlyGoverner {
_Companies._approveCompany(_CpnyAddr);
emit companyRegistrationApproved(msg.sender, _CpnyAddr);
}

function getAllCompanies() public view returns (address[] memory) {
return _Companies.getAllCompanies();
}

function isCompanyRegistered(address _CpnyAddr) public view returns (bool) {
return _Companies.isRegistered(_CpnyAddr);
}

function isCompanyApproved(address _CpnyAddr) public view returns (bool) {
return _Companies.isApproved(_CpnyAddr);
}

function getEcoinPrice(address _CpnyAddr) public view returns (int) {
return _Companies.getEcoinPrice(_CpnyAddr);
}


function buyecoinFromCompany(address _CpnyAddr, int numofecoin,OrderAvailability _orderAvailability)
public
payable
{
require(isCompanyApproved(_CpnyAddr) == true, "Company not approved");
int rate = getEcoinPrice(_CpnyAddr);
int cost = rate * numofecoin;
uint256 paymentWei = msg.value;
uint256 paymentSTT = (paymentWei * conversionRate) / (10**18);
OrderAvailability oa= _orderAvailability;
require(int(paymentSTT) >= cost, "Not enough STT");

_transfer(msg.sender, _CpnyAddr, paymentSTT);
_Companies.reducedecoin(_CpnyAddr, numofecoin);
//ShareDetailsMap[msg.sender][_CpnyAddr] += numOfStocks;
ECoin.transfer(_CpnyAddr,msg.sender,numofecoin,"ok");
emit EcoinPurchase(
msg.sender,
_CpnyAddr,
_CpnyAddr,
numofecoin,
paymentSTT,
oa
);
}

function postecoinforSale(
address _CpnyAddr,
int numberofecoin,
uint256 Price,
OrderAvailability _orderAvailability//(uint _quantity, uint _stockPrice, OrderSide _orderSide, OrderType _orderType, OrderAvailability _orderAvailability)
) public payable returns (uint256) {
uint256 saleID = getNewSaleID();
SalePosts[saleID] = SalePost({
Company: _CpnyAddr,
Seller: msg.sender,
numberofecoin: numberofecoin,
price: Price
});

emit EcoinPostForSale(msg.sender,_CpnyAddr, numberofecoin, Price,_orderAvailability);
return saleID;
}

function buyPostedecoin(uint256 _saleID,OrderAvailability _orderAvailability) public payable {
require(SalePosts[_saleID].numberofecoin> 0, "Post not found");
SalePost memory SP = SalePosts[_saleID];
address company=SP.Company;
address seller=SP.Seller;
int nunofecoin=SP.numberofecoin;
uint256 cost = SP.price;
uint256 paymentWei = msg.value;
uint256 paymentSTT = (paymentWei * conversionRate) / (10**18);
OrderAvailability oa= _orderAvailability;
require(paymentSTT >= cost, "Not enough STT");

_transfer(msg.sender, SP.Seller, paymentSTT);
ECoin.transfer(company,seller,nunofecoin,"ok");

emit EcoinPurchase(
msg.sender,
SP.Seller,
SP.Company,
SP.numberofecoin,
paymentSTT,
oa
);
}
}
/*
/
/
/

//


/




/


/

*/
library SafeMath {

    /// @dev Multiplies two numbers, reverts on overflow.
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "MUL_ERROR");

        return c;
    }

    /// @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "DIVIDING_ERROR");
        uint256 c = a / b;
        return c;
    }

    /// @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SUB_ERROR");
        uint256 c = a - b;
        return c;
    }

    /// @dev Adds two numbers, reverts on overflow.
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "ADD_ERROR");
        return c;
    }

    /// @dev Divides two numbers and returns the remainder (unsigned integer modulo), reverts when dividing by zero.
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "MOD_ERROR");
        return a % b;
    }
}







contract Auction {
    // static
    address public owner;
    uint public bidIncrement;
    uint public startBlock;
    uint public endBlock;
    string public ipfsHash;

    // state
    bool public canceled;
    uint public highestBindingBid;
    address public highestBidder;
    mapping(address => uint256) public fundsByBidder;
    bool ownerHasWithdrawn;

    event LogBid(address bidder, uint bid, address highestBidder, uint highestBid, uint highestBindingBid);
    event LogWithdrawal(address withdrawer, address withdrawalAccount, uint amount);
    event LogCanceled();

    constructor( address _owner,uint   _bidIncrement, uint   _startBlock, uint   _endBlock, string memory  _ipfsHash) public{
        if (_startBlock >= _endBlock) revert();
        if (_startBlock < block.number) revert();
        if (_owner == address(0x0)) revert();

        owner = _owner;
        bidIncrement = _bidIncrement;
        startBlock = _startBlock;
        endBlock = _endBlock;
        ipfsHash = _ipfsHash;
    }

    function  getHighestBid() public view
        returns (uint)
    {
        return fundsByBidder[highestBidder];
    }

    function placeBid() public
        payable
        onlyAfterStart
        onlyBeforeEnd
        onlyNotCanceled
        onlyNotOwner
        returns (bool success)
    {
        // reject payments of 0 ETH
        if (msg.value == 0) revert();

        // calculate the user's total bid based on the current amount they've sent to the contract
        // plus whatever has been sent with this transaction
        uint newBid = fundsByBidder[msg.sender] + msg.value;

        // if the user isn't even willing to overbid the highest binding bid, there's nothing for us
        // to do except revert the transaction.
        if (newBid <= highestBindingBid) revert();

        // grab the previous highest bid (before updating fundsByBidder, in case msg.sender is the
        // highestBidder and is just increasing their maximum bid).
        uint highestBid = fundsByBidder[highestBidder];

        fundsByBidder[msg.sender] = newBid;

        if (newBid <= highestBid) {
            // if the user has overbid the highestBindingBid but not the highestBid, we simply
            // increase the highestBindingBid and leave highestBidder alone.

            // note that this case is impossible if msg.sender == highestBidder because you can never
            // bid less ETH than you've already bid.

            highestBindingBid = min(newBid + bidIncrement, highestBid);
        } else {
            // if msg.sender is already the highest bidder, they must simply be wanting to raise
            // their maximum bid, in which case we shouldn't increase the highestBindingBid.

            // if the user is NOT highestBidder, and has overbid highestBid completely, we set them
            // as the new highestBidder and recalculate highestBindingBid.

            if (msg.sender != highestBidder) {
                highestBidder = msg.sender;
                highestBindingBid = min(newBid, highestBid + bidIncrement);
            }
            highestBid = newBid;
        }

        emit LogBid(msg.sender, newBid, highestBidder, highestBid, highestBindingBid);
        return true;
    }

    function min(uint a, uint b)
        private
        view
        returns (uint)
    {
        if (a < b) return a;
        return b;
    }

    function cancelAuction() public
        onlyOwner
        onlyBeforeEnd
        onlyNotCanceled
        returns (bool success)
    {
        canceled = true;
        emit LogCanceled();
        return true;
    }

    function withdraw() public
        onlyEndedOrCanceled
        returns (bool success)
    {
        address  withdrawalAccount;
        uint withdrawalAmount;

        if (canceled) {
            // if the auction was canceled, allowed to withdraw funds
            withdrawalAccount = msg.sender;
            withdrawalAmount = fundsByBidder[withdrawalAccount];

        } else {
            // the auction finished without being canceled

            if (msg.sender == owner) {
                // the auction's owner allowed to withdraw the highestBindingBid
                withdrawalAccount = highestBidder;
                withdrawalAmount = highestBindingBid;
                ownerHasWithdrawn = true;

            } else if (msg.sender == highestBidder) {
                // the highest bidder should only be allowed to withdraw the difference between their
                // highest bid and the highestBindingBid
                withdrawalAccount = highestBidder;
                if (ownerHasWithdrawn) {
                    withdrawalAmount = fundsByBidder[highestBidder];
                } else {
                    withdrawalAmount = fundsByBidder[highestBidder] - highestBindingBid;
                }

            } else {
                // anyone who participated but did not win the auction should be allowed to withdraw
                // the full amount of their funds
                withdrawalAccount = msg.sender;
                withdrawalAmount = fundsByBidder[withdrawalAccount];
            }
        }

        if (withdrawalAmount == 0) revert();

        fundsByBidder[withdrawalAccount] -= withdrawalAmount;

        // send the funds
        if (!payable(msg.sender).send(withdrawalAmount)) revert();

        emit LogWithdrawal(msg.sender, withdrawalAccount, withdrawalAmount);

        return true;
    } 

    modifier onlyOwner {
        if (msg.sender != owner) revert();
        _;
    }

    modifier onlyNotOwner {
        if (msg.sender == owner) revert();
        _;
    }

    modifier onlyAfterStart {
        if (block.number < startBlock) revert();
        _;
    }

    modifier onlyBeforeEnd {
        if (block.number > endBlock) revert();
        _;
    }

    modifier onlyNotCanceled {
        if (canceled) revert();
        _;
    }

    modifier onlyEndedOrCanceled {
        if (block.number < endBlock && !canceled) revert();
        _;
    }
}








contract OrderBook {

    string private symbol;
    uint private price;

    Order[] public bids;
    Order[] public asks;

    mapping(address => uint) ownedStocks;

    uint private marketBuyPercent = 5;

    enum OrderSide {BUY, SELL}
    enum OrderType {LIMIT, MARKET}
    enum OrderAvailability {OPEN, FOK, IOC}

    struct Order {
        uint timestamp;
        address investor;

        uint quantity;
        uint price;

        OrderSide orderSide;
        OrderType orderType;
        OrderAvailability orderAvailability;
    }

    function OrdeBook(string memory _symbol, uint _quantity, uint _marketBuyPercent) public stringLength(_symbol, 3) {
        symbol = _symbol; 
        ownedStocks[msg.sender] = _quantity;
        marketBuyPercent = _marketBuyPercent;
    }

    function placeOrder(uint _quantity, uint _stockPrice, OrderSide _orderSide, OrderType _orderType, OrderAvailability _orderAvailability) external payable {
        require(_quantity > 0);
        require(_stockPrice > 0);

        if (_orderSide == OrderSide.BUY) {
            if (_orderType == OrderType.LIMIT) {
                require(msg.value == _stockPrice * _quantity);
            }

            if (_orderType == OrderType.MARKET) {
                require(msg.value >= ((100 + marketBuyPercent) * price * _quantity) / 100);
            }
        } else {
            require(ownedStocks[msg.sender] >= _quantity);
            require(msg.value == 0);
        }

        Order memory order = Order(block.timestamp,  msg.sender, _quantity, _stockPrice, _orderSide, _orderType, _orderAvailability);

        if (_orderAvailability == OrderAvailability.FOK) {
            if (!canExecuteEntireOrder(order)) {
                address payable a=payable(msg.sender);
                a.transfer(msg.value);
                return;
            }
        }

        executeOrder(order);
    }

    function canExecuteEntireOrder(Order memory _order) private returns (bool) {
        Order[] storage oppositeSideOrders = _order.orderSide == OrderSide.BUY ? asks : bids;
        uint oppositeSideOrdersLength = oppositeSideOrders.length;

        uint position = 0;
        uint totalQuantity = 0;

        while (position < oppositeSideOrdersLength) {
            Order storage currentOrder = oppositeSideOrders[position++];

            if (_order.orderType == OrderType.MARKET) {
                totalQuantity += currentOrder.quantity;
            }

            if (_order.orderType == OrderType.LIMIT) {
                if (isPriceOk(_order, currentOrder)) {
                    totalQuantity += currentOrder.quantity;
                }
            }

            if (totalQuantity >= _order.quantity) {
                return true;
            }
        }

        return false;
    }

    function isPriceOk(Order memory _myOrder, Order memory _otherOrder) private returns (bool) {
        if (_myOrder.orderSide == OrderSide.BUY) {
            if (_myOrder.price >= _otherOrder.price) {
                return true;
            }
        } else {
            if (_myOrder.price <= _otherOrder.price) {
                return true;
            }
        }

        return false;
    }

    function executeOrder(Order memory _order) public payable{
        Order[] storage oppositeOrders = _order.orderSide == OrderSide.BUY ? asks : bids;

        uint amountToReturn = msg.value;
        uint remainingStocks = _order.quantity;

        while (remainingStocks > 0) {
            if (oppositeOrders.length == 0) {
                if (_order.orderAvailability == OrderAvailability.IOC || _order.orderType == OrderType.MARKET) {
                    // do nothing. Order is canceled
                    payable(_order.investor).transfer(amountToReturn);
                }

                if (_order.orderAvailability == OrderAvailability.OPEN) {
                    _order.quantity = remainingStocks;
                    placeOrderInCorrectPlace(_order);
                }

                break;
            }

            Order storage orderToMatch = oppositeOrders[0];

            if (_order.orderType == OrderType.MARKET) {
                if (remainingStocks >= orderToMatch.quantity) {
                    actualExecutionOfOrder(_order, orderToMatch, orderToMatch.quantity);

                    remainingStocks -= orderToMatch.quantity;
                    amountToReturn -= orderToMatch.quantity * orderToMatch.price;
                    removeFirstElement(oppositeOrders);
                } else {
                    actualExecutionOfOrder(_order, orderToMatch, remainingStocks);
                    amountToReturn -= remainingStocks * orderToMatch.price;

                    orderToMatch.quantity -= remainingStocks;
                    remainingStocks = 0;
                }
            }

            if (_order.orderType == OrderType.LIMIT) {
                if (!isPriceOk(_order, orderToMatch)) {
                    _order.quantity = remainingStocks;
                    placeOrderInCorrectPlace(_order);
                    break;
                } else {
                    if (remainingStocks >= orderToMatch.quantity) {
                        actualExecutionOfOrder(_order, orderToMatch, orderToMatch.quantity);

                        amountToReturn -= orderToMatch.quantity * orderToMatch.price;
                        remainingStocks -= orderToMatch.quantity;
                        removeFirstElement(oppositeOrders);
                    } else {
                        actualExecutionOfOrder(_order, orderToMatch, remainingStocks);

                        amountToReturn -= remainingStocks * orderToMatch.price;
                        orderToMatch.quantity -= remainingStocks;
                        remainingStocks = 0;
                    }
                }
            }
        }
    }

    function actualExecutionOfOrder(Order memory _myOrder, Order memory _orderToMatch, uint _quantityToTransfer) public {
        if (_myOrder.orderSide == OrderSide.BUY) {
            ownedStocks[_orderToMatch.investor] -= _quantityToTransfer;
            ownedStocks[_myOrder.investor] += _quantityToTransfer;

            payable(_orderToMatch.investor).transfer(_quantityToTransfer * _orderToMatch.price);
        } else {
            ownedStocks[_orderToMatch.investor] += _quantityToTransfer;
            ownedStocks[_myOrder.investor] -= _quantityToTransfer;

            payable(_myOrder.investor).transfer(_quantityToTransfer * _orderToMatch.price);
        }

        price = _orderToMatch.price;
    }

    function removeFirstElement(Order[] storage _orders) private {
        if (_orders.length == 0) {
            return;
        }

        delete _orders[0];

        for (uint i = 0; i < _orders.length - 1; i++) {
            _orders[i] = _orders[i + 1];
        }

        _orders.push();
    }

    function addElementAtPosition(Order[] storage  _orders, uint  _position, Order memory _order) private {
        if (_orders.length == 0) {
            _orders.push(_order);
            return;
        }

        uint length = _orders.length;
        _orders.pop();

        for (uint i = length; i > _position; i--) {
            _orders[i] = _orders[i - 1];
        }

        _orders[_position] = _order;
    }

    function placeOrderInCorrectPlace(Order memory _order) private {
        bool inserted = false;
        Order[] storage sameSideOrders = _order.orderSide == OrderSide.BUY ? bids : asks;
        uint sameSideOrdersLength = sameSideOrders.length;
        uint a=0;
        for (  uint i=1; i < sameSideOrdersLength; i++) {
            if (_order.orderSide == OrderSide.SELL) {
                if (_order.price < asks[i].price) {
                    addElementAtPosition(asks, i, _order);
                    inserted = true;
                    a=i;
                    break;
                }

                if (_order.price == asks[i].price) {
                    if (_order.quantity > asks[i].quantity) {
                        addElementAtPosition(asks, i, _order);
                        inserted = true;
                        a=i;
                        break;
                    } else {
                        addElementAtPosition(asks, i + 1, _order);
                        inserted = true;
                        a=i;
                        break;
                    }
                }
            } else {
                if (_order.price > bids[i].price) {
                    addElementAtPosition(bids, i, _order);
                    inserted = true;
                    a=i;
                    break;
                }

                if (_order.price == bids[i].price) {
                    if (_order.quantity > bids[i].quantity) {
                        addElementAtPosition(bids, i, _order);
                        inserted = true;
                        a=i;
                        break;
                    }
                }
            }
        }

        if (!inserted && _order.orderSide == OrderSide.BUY) {
            addElementAtPosition(bids, a, _order);
        }

        if (!inserted && _order.orderSide == OrderSide.SELL) {
            addElementAtPosition(asks, a, _order);
        }
    }

    modifier stringLength(string memory _str, uint _length) {
        require(bytes(_str).length == _length);
        _;
    }

    function getQuantityOfStocks() external view returns (uint){
        return ownedStocks[msg.sender];
    }

    function viewPrice() external view returns (uint){
        return price;
    }
}