import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import List "mo:base/List";
import Time "mo:base/Time";
import Hash "mo:base/Hash";

module Types = {

  public let CREATECANVAS_CYCLES: Nat = 200_000_000_000;  //0.1 T
  //Anonymous Principal 
  public let ANONYMOUS_PRINCIPAL : Text = "2vxsx-fae";
  public type Result<T,E> = Result.Result<T,E>;
  public type TokenIndex = Nat;

  public type Balance = Nat;

  public let FACTORY_SETTINGS: FactorySettingsMu = {
      maxSupply = 5000;
      maxForkRoyaltyRatio = 2; //
      maxForkFee = 20_000_000; //
      maxNameSize = 20; //
      maxDescSize = 2000; //
      maxCategorySize = 20; //
      var createFee = 100_000_000;
  };
  
  public type FactorySettings = {
    maxSupply: Nat;
    maxForkRoyaltyRatio: Nat;
    maxForkFee: Nat;
    maxNameSize: Nat;
    maxDescSize: Nat;
    maxCategorySize: Nat;
    createFee : Nat;
  };

   public type FactorySettingsMu= {
    maxSupply: Nat;
    maxForkRoyaltyRatio: Nat;
    maxForkFee: Nat;
    maxNameSize: Nat;
    maxDescSize: Nat;
    maxCategorySize: Nat;
    var createFee : Nat;
  };


  public let COLLECTION_SETTINGS: CollectionSettingsMu = {
      maxNameSize = 20; 
      maxDescSize = 2000; 
      maxCategorySize = 20; 
      maxAttrNum = 10;
      uploadProtocolFeeRatio = 10;
      var maxRoyaltyRatio = 7; 
      var uploadProtocolBaseFee = 1_000_000; //0.01 WICP
      var marketFeeRatio = 1;
      var forkRoyaltyRatio = null;
      var newItemForkFee = null;
      var totalSupply = 0;
  };
  
  public type CollectionSettingsMu = {
    maxNameSize: Nat;
    maxDescSize: Nat;
    maxCategorySize: Nat;
    maxAttrNum: Nat;
    uploadProtocolFeeRatio : Nat; 
    var maxRoyaltyRatio: Nat;
    var uploadProtocolBaseFee : Nat;
    var marketFeeRatio : Nat;
    var forkRoyaltyRatio : ?Nat;
    var newItemForkFee : ?Nat;
    var totalSupply : Nat;
  };

  public type CollectionSettings = {
    maxRoyaltyRatio: Nat;  
    maxNameSize: Nat;
    maxDescSize: Nat;
    maxCategorySize: Nat;
    maxAttrNum: Nat;
    //uploadProtocolFee = uploadProtocolBaseFee + uploadProtocolFeeRatio * newItemForkFee / 100
    uploadProtocolBaseFee : Nat; 
    uploadProtocolFeeRatio : Nat;
    newItemForkFee : ?Nat;    //fee belong to CCC when upload new item
    marketFeeRatio : Nat;     //royalty ratio belong to CCC when buynow
    forkRoyaltyRatio : ?Nat;  //royalty ratio belong to collection owner when buynow
    totalSupply : Nat;
  };

  public type  CollectionConf= {
    name: Text;
    desc: Text;
    category: Text;
    webLink: ?Text;
    twitter: ?Text;
    discord: ?Text;
    medium: ?Text;
  };
  
  public type ContentInfo = {
    name: Text;
    desc: Text;
    category: Text;
    webLink: ?Text;
    twitter: ?Text;
    discord: ?Text;
    medium: ?Text;
  };

  public type CollectionParamInfo = {
    contentInfo: ContentInfo;
    forkRoyaltyRatio: ?Nat;
    forkFee: ?Nat;
    totalSupply: Nat;
    logo: ?Blob;
    featured: ?Blob;
    banner: ?Blob;
  };

  public type CollectionInfo = {
    owner: Principal;
    cid: Principal;
    name: Text;
    desc: Text;
    category: Text;
    forkRoyaltyRatio: ?Nat;
    forkFee: ?Nat;
    totalSupply: Nat;
  };

  public type AttrStru = {
    attrIds: [Nat];
  };

  public type NewItem = {
    name: Text;
    desc: Text;
    orignData: Blob;
    earnings: ?Nat;
    royalty: ?Principal;
    thumbnailData: ?Blob;
    attrArr: [ComponentAttribute];
  };

  public type NewIPFSItem = {
    //为null表示该collection不支持fork，或者支持fork但是第一次上传token
    parentToken: ?TokenIndex; 
    name: Text;
    desc: Text;
    attrArr: [ComponentAttribute];
    photoLink: ?Text;
    videoLink: ?Text;
    earnings: Nat;
    royaltyFeeTo: Principal;
  };

  public type ComponentAttribute = {
    traitType: Text;
    name: Text;
  };

  public type NFTMetaData = {
    index: TokenIndex;
    parentToken: ?TokenIndex;
    name: Text;
    desc: Text;
    photoLink: ?Text;
    videoLink: ?Text;
    royaltyRatio: Nat;
    royaltyFeeTo: Principal;
    attrIds: [Nat];
  };

  public type TokenDetails = {
    id: Nat;
    attrArr: [ComponentAttribute];
  };

  public type GetTokenResponse = Result.Result<TokenDetails, {
    #NotFoundIndex;
  }>;


  public type BuyRequest = {
    tokenIndex:     TokenIndex;
    price:          Nat;
    feeTo:          Principal;
    marketFeeRatio: Nat;
  };

  public type CreateError = {
    #Unauthorized;
    #LessThanFee;
    #InsufficientBalance;
    #AllowedInsufficientBalance;
    #NameAlreadyExit;
    #EarningsTooHigh;
    #NotOwner;
    #NotSetDataUser;
    #SupplyTooLarge;
    #RoyaltyRatioTooHigh;
    #ParamError;
    #NotOnWhiteList;
    #Other;
  };

  public type CreateResponse = Result.Result<Text, CreateError>;

  public type MintError = {
    #Unauthorized;
    #LessThanFee;
    #InsufficientBalance;
    #AllowedInsufficientBalance;
    #Other;
    #NotOwner;
    #ParamError;
    #SupplyUsedUp;
    #IPFSLinkAlreadyExist;
    #TooManyAttr;
    #NoIPFSLink;
  };
  public type MintResponse = Result.Result<TokenIndex,MintError>;

  public type TransferResponse = Result.Result<TokenIndex, {
    #NotOwnerOrNotApprove;
    #NotAllowTransferToSelf;
    #ListOnMarketPlace;
    #Other;
  }>;

  public type BuyResponse = Result.Result<TokenIndex, {
    #Unauthorized;
    #LessThanFee;
    #InsufficientBalance;
    #AllowedInsufficientBalance;
    #NotFoundIndex;
    #NotAllowBuySelf;
    #AlreadyTransferToOther;
    #Other;
  }>;

  public type ListRequest = {
    tokenIndex : TokenIndex;
    price : Nat;
  };

  public type Listings = { 
    tokenIndex : TokenIndex; 
    seller : Principal; 
    price : Nat;
    time : Time.Time;
  };

  public type SoldListings = {
    lastPrice : Nat;
    time : Time.Time;
    account : Nat;
  };

  public type Operation = {
    #Mint;
    #List;
    #UpdateList;
    #CancelList;
    #Sale;
    #Transfer;
    #Bid;
  };

  public type OpRecord = {
    op: Operation;
    price: ?Nat;
    from: ?Principal;
    to: ?Principal;
    timestamp: Time.Time;
  };

  public type SaleRecord = {
    tokenIndex: TokenIndex;
    price: ?Nat;
    from: ?Principal;
    to: ?Principal;
    photoLink: ?Text;
    videoLink: ?Text;
    timestamp: Time.Time;
  };

  public type AncestorMintRecord = {
    index: Nat;
    record: OpRecord;
  };

  public type ListResponse = Result.Result<TokenIndex, {
    #NotOwner;
    #NotFoundIndex;
    #AlreadyList;
    #NotApprove;
    #NotNFT;
    #SamePrice;
    #NotOpenList;
    #Other;
  }>;

  public module TokenIndex = {
    public func equal(x : TokenIndex, y : TokenIndex) : Bool {
      x == y
    };
    public func hash(x : TokenIndex) : Hash.Hash {
      Text.hash(Nat.toText(x))
    };
  };

  public module ComponentAttribute = {
    public func equal(x : ComponentAttribute, y : ComponentAttribute) : Bool {
      x.traitType == y.traitType and x.name == y.name
    };
    public func hash(x : ComponentAttribute) : Hash.Hash {
      Text.hash(x.traitType # x.name)
    };
  };

}

