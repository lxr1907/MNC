pragma solidity ^0.4.19;
contract owned {
    address public owner;
    function owned() public {
        owner = msg.sender;
    }
    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

contract LxrContract is owned{
    struct miner{
        //MNC余额
        uint256 balance;
        //挖矿份额
        uint256 mining;
        //上一次分红，衰减日期
        uint256 lastDate;
        //上一次收益
        uint256 lastBonus;
    }
    //虚拟币名称
    string public name;
    //虚拟币名称缩写
    string public symbol;
    //18 decimals 极力推荐使用默认值，尽量别改
    uint8 public constant decimals = 18;
    //和以太坊兑换的汇率
    uint32 public ethExchangeRate = 1000;
    //总发行
    uint256 public totalSupply;
    //创始人保留百分比
    uint8  constant ownerInitial=10;
    //合约拥有者
    address public owner;
    //创建所有账户余额数组
    mapping (address => miner) public miners;
    //挖矿需要募集的挖矿资金,100个eth，后续可以增加
    uint256 public collectAmountLeft=ethExchangeRate*100;
    //0.01个ETH起计算挖矿收益
    uint256  startMiningMin=ethExchangeRate/100;
    //挖矿人地址数组
    address[]  minersArray;
    //分红日期
    uint256 public bonusTimePoint;
    //分红历史总数
    uint256 public bonusTotal;
    //阶段分红累计数，分红后清零
    uint256 public bonusPeriodCumulative;
    //每日折旧率千分比,例如每日千分之2，一年后48.15%，3，一年后剩余33%，4一年后23.15%
    uint16 depreciationRate=3;
    //每次折旧时间，测试情况下设置为1分钟以便调试
    uint256 depreciationTime=1 minutes;
    //从挖矿账户提现手续费百分比
    uint miningDepositFee=30;
    // 在区块链上创建一个公共事件，它触发就会通知所有客户端
    event Transfer(address indexed from, address indexed to, uint256 value);
    event BalanceToMine(address indexed from, uint256 value);
    event MiningDeposit(address indexed from, uint256 value, uint256 fee);
    event TransferMining(address indexed from,address indexed to, uint256 value);
    event Bonus(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    /**
     * 初始化合约，将最初的令牌中的一部分打入创建者的账户中
     * @param initialSupply 初始发行量
     * @param tokenName 虚拟币名称
     * @param tokenSymbol 虚拟币名称缩写
     */
    function LxrContract(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        //初始化合约所有人
        owner=msg.sender;
        //合约账户余额初始
        _mintToken(this,initialSupply-initialSupply * ownerInitial/100);
        //所有人账户余额初始
        _mintToken(owner,initialSupply * ownerInitial/100);
        // 设置显示名称
        name = tokenName;     
        // 设置显示缩写，例如比特币是BTC
        symbol = tokenSymbol;               
        //初始化分红时间点
        bonusTimePoint=now/depreciationTime;
    }

    /**
     * 内部转账，只能被该合约调用
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // 检查发送者是否拥有足够的币
        require(miners[_from].balance >= _value);
        // 检查越界
        require(miners[_to].balance + _value > miners[_to].balance);
        // 从发送者扣币
        miners[_from].balance -= _value;
        // 给接收者加相同数量币
        miners[_to].balance += _value;
        //通知
        Transfer(_from, _to, _value);
    }
    /**
     * 账户余额兑换挖矿份额
     */
    function balanceToMining( uint256 _value) public {
        //检查挖矿募集剩余
        require(collectAmountLeft > 0);
        require(miners[msg.sender].balance > 0);
        uint256 effectValue=_value;
        //传0或不传则所有余额兑换挖矿份额
        if(effectValue==0){
            effectValue=miners[msg.sender].balance/(10**uint256(decimals));
        }
        // 检查越界
        require(miners[msg.sender].mining + effectValue > miners[msg.sender].mining);
        // 检查发送者是否拥有足够的币
        if(miners[msg.sender].balance < effectValue){
            effectValue=miners[msg.sender].balance/(10**uint256(decimals));
        }
        //检查挖矿募集剩余是否足够,不足只转一部分
        if(collectAmountLeft < _value){
            effectValue=collectAmountLeft;
        }
        //账户ETH余额不足，无法投资
        if(this.balance<effectValue* 10 ** uint256(decimals)/ethExchangeRate){
            return;
        }
        //如果不存在，将该挖矿地址加入数组，用于以后遍历访问
        addToMinersArray(msg.sender);
        // 从余额销毁
        burn(msg.sender,effectValue);
        // 给挖矿账户加相同数量币
        miners[msg.sender].mining += effectValue* 10 ** uint256(decimals);
        //募集剩余资金减少
        collectAmountLeft -=effectValue;
        //将挖矿所需以太坊转到拥有者账户，以便所有者使用这些eth购买矿机挖矿
        owner.transfer(effectValue* 10 ** uint256(decimals)/ethExchangeRate);
        //通知
        BalanceToMine(msg.sender, effectValue);
    }
    /**
     * 
     * 将挖矿份额转换为账户余额，需要按百分比支付手续费
     * 
     * @param _value 提出金额
     */
    function miningDeposit( uint256 _value) public {
        uint depositFee=_value* 10 ** uint256(decimals)*miningDepositFee/100; 
        uint depositValue=_value* 10 ** uint256(decimals);
        // 检查发送者是否拥有足够的币
        require(miners[msg.sender].mining >= depositValue);
        // 检查越界
        require(miners[msg.sender].balance + depositValue > miners[msg.sender].balance);
        // 从挖矿余额扣除
        miners[msg.sender].mining -= depositValue;
        //挖矿余额剩余为0，全部提现，则时间重置
        if(miners[msg.sender].mining==0){
            miners[msg.sender].lastDate=0;
        }
        //给账户加相同数量币,扣除一定百分比手续费
        miners[msg.sender].balance += depositValue-depositFee;
        //将手续费支付给合约管理员
        miners[owner].balance += depositFee;
        //通知
        MiningDeposit(msg.sender, depositValue,depositFee);
    }
    //将该挖矿地址加入数组
    function addToMinersArray(address _miner) internal{
        //如果不存在，将该挖矿地址加入数组，用于以后遍历访问
        bool hasAdd=false;
        for (uint i = 0; i < minersArray.length; i++) {
            if(minersArray[i]==_miner){
                hasAdd=true;
                break;
            }
        }
        if(!hasAdd){
            minersArray.push(_miner);   
        }
    }
    /**
     * 将挖矿份额转让
     */
    function transferMining(address _to, uint256 _value)  public {
         // 检查发送者是否拥有足够的币
        require(miners[msg.sender].mining >= _value);
        // 检查越界
        require(miners[_to].mining + _value > miners[_to].mining);
        //将该挖矿地址加入数组
        addToMinersArray(_to);
        // 从发送者扣币
        miners[msg.sender].mining -= _value;
        // 给接收者加相同数量币
        miners[_to].mining += _value;
        TransferMining(msg.sender,_to,  _value);
    }
    /**
     *计算总挖矿份额 
     */
    function getMiningAmountTotal() public view returns ( uint256 _totalMinigAmount){
        for (uint i = 0; i < minersArray.length; i++) {
            uint256 miningAmount = miners[minersArray[i]].mining;
            _totalMinigAmount += miningAmount;
        }
        _totalMinigAmount=_totalMinigAmount/(10**uint256(decimals));
    }
    /**
     *根据挖矿份额给每个人分红 ,匿名方法，直接转账触发
     * bonusMNCtoMiner
     */
    function () payable public {
        //阶段收益MNC
        bonusPeriodCumulative += msg.value*ethExchangeRate;
        require(bonusPeriodCumulative>0);
        //该阶段已经分红过，只累加分红数量
        if(bonusTimePoint>=now/depreciationTime){
            return;
        }
        //更新分红时间点
        bonusTimePoint=now/depreciationTime;
        uint256 totalMinigAmount=getMiningAmountTotal();
        if(totalMinigAmount==0){
            return;
        }
        //加发行量
        _mintToken(this,bonusPeriodCumulative/(10**uint256(decimals)));
        //总历史收益增加
        bonusTotal += bonusPeriodCumulative;
        //计算每个人的收益
        for (uint i = 0; i < minersArray.length; i++) {
            uint256 miningAmount = miners[minersArray[i]].mining/(10**uint256(decimals));
            if(miningAmount<startMiningMin){
                continue;
            }
             //矿机折旧衰减
            if(miners[minersArray[i]].lastDate==0){
                //第一次不折旧，记录时间
                miners[minersArray[i]].lastDate=now/depreciationTime;
                //第一次也不分红
                continue;
            }else{
                //计算出衰减段数
                uint256 depreciationPeriods=now/depreciationTime-miners[minersArray[i]].lastDate;
                //每段衰减一次
                for(uint m=0;m<depreciationPeriods;m++)
                miners[minersArray[i]].mining=miners[minersArray[i]].mining* (1000-depreciationRate)/1000;
                //更新时间
                miners[minersArray[i]].lastDate=now/depreciationTime;
            }
            //分红数量
            uint256 oneBonus = bonusPeriodCumulative*miningAmount/totalMinigAmount;
            miners[minersArray[i]].lastBonus=oneBonus;
        }
        //阶段收益清零
        bonusPeriodCumulative=0;
         //发放收益
        for (uint j = 0; j < minersArray.length; j++) {
            bonusToken(minersArray[j]);
        }
    }
    /**
     *奖励挖矿收益MNC
     * 
     */
    function bonusToken(address _to) internal{
        miners[_to].balance+= miners[_to].lastBonus ;
        Bonus(_to, miners[_to].lastBonus*(10**uint256(decimals)));
    }
    /**
     * 发送MNC
     *
     * 从你的账户发送个`_value` 令牌到 `_to` 
     *
     * @param _to 接收地址
     * @param _value 发送数量
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }
    /**
     *增发MNC
     * 
     */
    function _mintToken(address _to, uint256 mintedAmount) internal{
        totalSupply += mintedAmount*(10**uint256(decimals));
        miners[_to].balance+= mintedAmount*(10**uint256(decimals));
        Transfer(0, _to, mintedAmount*(10**uint256(decimals)));
    }
    //增发MNC
    function MintToken( uint256 mintedAmount) onlyOwner public{
        _mintToken(this,mintedAmount);
    }
    /**
     *销毁MNC
     * 
     */
    function burn( address _from,uint256 mintedAmount) internal{
        totalSupply -= mintedAmount*(10**uint256(decimals));
        miners[_from].balance-= mintedAmount*(10**uint256(decimals));
        Burn(_from, mintedAmount*(10**uint256(decimals)));
    }
    /**
     * 
     *增加募集金额
     * @param amount 需要的MNC数量
     */
    function addCollection( uint256 amount) onlyOwner  public{
        collectAmountLeft += amount;
    }
   
    /// 使用以太坊购买token
    function buy() payable public {
        uint amount = msg.value;
        //合约余额充足         
        require(miners[this].balance>=amount * ethExchangeRate);
        _transfer( this,msg.sender, amount * ethExchangeRate);
    }
    //出售token换回以太坊
    function sell(uint256 amount)  public {
        _transfer(msg.sender, this, amount* 10 ** uint256(decimals));             
        msg.sender.transfer(amount* 10 ** uint256(decimals)/ethExchangeRate);          
    }
    //调整和以太坊的兑换比例
    function setEthMncRate(uint32 _rate) onlyOwner public{
        //调整幅度限制到原价20%
        require(_rate>ethExchangeRate*8/10);
        require(_rate<ethExchangeRate*12/10);
        ethExchangeRate=_rate;
    }
    //折旧率千分比调整
    function setDepreciationRate(uint16 _rate) onlyOwner public{
        //调整幅度限制到100%
        require(_rate>depreciationRate/2);
        require(_rate<depreciationRate*2);
        require(_rate<1000);
        depreciationRate=_rate;
    }
    //折旧时间调整
    function setDepreciationTime(uint8 _rate) onlyOwner public{
        require(_rate!=0);
        //天数
        depreciationTime=_rate*1 days;
        //初始化分红时间点
        bonusTimePoint=now/depreciationTime;
    }
    //-------------------------------------------一下为调试方法
    //获取当前分红时间
    function getBonusTimeNow() public view returns(uint256 _time){
       _time= now/depreciationTime;
    } /**
     * 
     *获取合约余额
     */
    function getContractBalance( )  public view   returns (uint _contractBalance,uint _ethBanlance){
       _contractBalance=miners[this].balance/(10**uint256(decimals));
       _ethBanlance=this.balance/(10**uint256(decimals));
    }
    /**
     * 
     *获取我的余额
     */
    function getMyBalance( )  public view   returns (uint _myBalance,uint _myMining,uint _lastBonus,uint _date){
       _myBalance=miners[msg.sender].balance/(10**uint256(decimals));
       _myMining=miners[msg.sender].mining/(10**uint256(decimals));
       _lastBonus=miners[msg.sender].lastBonus/(10**uint256(decimals));
       _date=miners[msg.sender].lastDate;
    }
}
