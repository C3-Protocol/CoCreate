/**
 * Module     : NFTFactory.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import WICP "../common/WICP";
import Types "../common/types";
import IC0 "../common/IC0";
import NFTTypes "../common/nftTypes";
import NFT "../NFT/NFT";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import List "mo:base/List";
import Option "mo:base/Option";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";

/**
 * Factory Canister to Create Canister
 */
shared(msg)  actor class NFTFactory (owner_: Principal, wicpCanisterId_: Principal) = this {

    type WICPActor = WICP.WICPActor;
    type CollectionIndex = Types.TokenIndex;
    type CollectionInfo = Types.CollectionInfo;
    type CollectionParamInfo = Types.CollectionParamInfo;
    type CreateResponse = Types.CreateResponse;
    type CreateError = Types.CreateError;
    type FactorySettings = Types.FactorySettings;
    type FactorySettingsMu = Types.FactorySettingsMu;

    private stable var owner: Principal = owner_;
    private stable var createFeeTo : Principal = owner_;
    private stable var WICPCanisterActor: WICPActor = actor(Principal.toText(wicpCanisterId_));

    private stable var cyclesCreateCanvas: Nat = Types.CREATECANVAS_CYCLES;
    private stable var factorySettings: FactorySettingsMu = Types.FACTORY_SETTINGS;

    private stable var collectionInfoEntries : [(Text, CollectionInfo)] = [];
    private var collectionInfo = HashMap.HashMap<Text, CollectionInfo>(1, Text.equal, Text.hash); 

    private stable var dataUser : Principal = Principal.fromText(Types.ANONYMOUS_PRINCIPAL);

    private stable var whiteListEntries : [(Principal, Nat)] = [];
    private var whiteList = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

    private stable var bPublic: Bool = false;

    system func preupgrade() {
        
        collectionInfoEntries := Iter.toArray(collectionInfo.entries());
        whiteListEntries := Iter.toArray(whiteList.entries());
    };

    system func postupgrade() {
        collectionInfo := HashMap.fromIter<Text, CollectionInfo>(collectionInfoEntries.vals(), 1, Text.equal, Text.hash);
        whiteList := HashMap.fromIter<Principal, Nat>(whiteListEntries.vals(), 1, Principal.equal, Principal.hash);

        collectionInfoEntries := [];
        whiteListEntries := [];
    };

    private func _isOwner(user: Principal) : Bool {
        dataUser == user or owner == user 
    };

    public shared(msg) func createNewCollection(paramInfo: CollectionParamInfo) : async CreateResponse {   
        //factory对外公开时或者不公开期间在白名单才能创建collection
        var availableMintTimes = 0;
        if (not bPublic){
            availableMintTimes := switch(whiteList.get(msg.caller)){
                case (?b){b};
                case _ {return #err(#NotOnWhiteList);};
            };
        };
        
        switch(_checkCollectionParam(paramInfo)){
            case(#ok(_)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };
       
        if(not _isOwner(msg.caller)){
            let transferResult = await WICPCanisterActor.transferFrom(msg.caller, createFeeTo, factorySettings.createFee);
            switch(transferResult){
                case(#ok(b)) {};
                case(#err(errText)){
                    return #err(errText);
                };
            };
        };

        Cycles.add(cyclesCreateCanvas);

        let collection = await NFT.NFT(paramInfo, msg.caller, owner, createFeeTo, wicpCanisterId_, _isOwner(msg.caller));
        let canisterId = Principal.fromActor(collection);
        let collInfo: CollectionInfo = {
            owner = msg.caller;
            cid = canisterId;
            name = paramInfo.contentInfo.name;
            desc = paramInfo.contentInfo.desc;
            category = paramInfo.contentInfo.category;
            forkRoyaltyRatio = paramInfo.forkRoyaltyRatio;
            forkFee = paramInfo.forkFee;
            totalSupply = paramInfo.totalSupply;
        };
        collectionInfo.put(paramInfo.contentInfo.name, collInfo);

        if (not bPublic){
            if (availableMintTimes == 1) {
                whiteList.delete(msg.caller);
            }else{
                whiteList.put(msg.caller,availableMintTimes - 1);
            };
        };

        ignore _setController(canisterId);
        return #ok(paramInfo.contentInfo.name);
    };

    public query func isPublic() : async Bool {
        bPublic
    };

    public shared(msg) func setbPublic(isPublic: Bool) : async Bool {
        assert(msg.caller == owner);
        bPublic := isPublic;
        return true;
    };

    public shared(msg) func uploadWhiteList(accountList: [Principal]) : async Bool {
        assert(msg.caller == owner);
        for(value in accountList.vals()){
            switch(whiteList.get(value)){
                case (?b){
                    whiteList.put(value, b+1);
                };
                case _ {
                    whiteList.put(value, 1);
                };
            }
        };
        return true;
    };

    public shared(msg) func clearWhiteList() : async Bool {
        assert(msg.caller == owner);
        whiteList := HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
        return true;
    };
    
    public query func getWhiteList() : async [(Principal, Nat)] {
        Iter.toArray(whiteList.entries())
    };

    public query func checkIfWhiteList(user: Principal) : async Nat {
        switch(whiteList.get(user)){
            case (?b){b};
            case _ {0};
        }
    };


    private func _checkCollectionParam(paramInfo: CollectionParamInfo) : Result.Result<(), CreateError> {
        if(_checkProNameExist(paramInfo.contentInfo.name)){return #err(#NameAlreadyExit);};
        if(Principal.isAnonymous(dataUser)) {return #err(#NotSetDataUser);};
        if(paramInfo.totalSupply > factorySettings.maxSupply) {return #err(#SupplyTooLarge);};

        if( paramInfo.contentInfo.name.size() > factorySettings.maxNameSize 
            or paramInfo.contentInfo.desc.size() > factorySettings.maxDescSize 
            or paramInfo.contentInfo.category.size() > factorySettings.maxCategorySize 
        ){
                return #err(#ParamError);
        };

        switch(paramInfo.forkRoyaltyRatio){
            case(?ratio) {
                if(ratio > factorySettings.maxForkRoyaltyRatio){
                    return #err(#RoyaltyRatioTooHigh);
                };
            };
            case(_){};
        };
        #ok()
    };

    public query func checkProjectName(pName: Text) : async Bool {
        _checkProNameExist(pName)
    };

    private func _checkProNameExist(pName: Text) : Bool {
        Option.isSome(collectionInfo.get(pName))
    };

    public query func getAllCollInfo() : async [(Text, CollectionInfo)]{
        Iter.toArray(collectionInfo.entries())
    };

    public query func getCollInfoByUser(prinId: Principal) : async [CollectionInfo] {

        var ret : List.List<CollectionInfo> = List.nil<CollectionInfo>();
        for( (k,v) in collectionInfo.entries()){
            if(prinId == v.owner){
                ret := List.push(v, ret);
            };
        };
        List.toArray(ret)
    };

    public query func getPublicCollInfo() : async [CollectionInfo] {

        var ret : List.List<CollectionInfo> = List.nil<CollectionInfo>();
        for( (k,v) in collectionInfo.entries()){
            if(_isOwner(v.owner)){
                ret := List.push(v, ret);
            };
        };
        List.toArray(ret)
    };

    public query func getCollInfoByCategory(category: Text) : async [CollectionInfo] {

        var ret : List.List<CollectionInfo> = List.nil<CollectionInfo>();
        for( (k,v) in collectionInfo.entries()){
            if(category == v.category){
                ret := List.push(v, ret);
            };
        };
        List.toArray(ret)
    };

    public shared(msg) func setCreateFee(price: Nat) : async Bool {
        assert(msg.caller == owner);
        factorySettings.createFee := price;
        return true;
    };

    public shared(msg) func setDataUser(_dataUser: Principal) : async Bool {
        assert(msg.caller == owner);
        dataUser := _dataUser;
        return true;
    };

    public query func getDataUser() : async Principal {
        dataUser
    };

    public shared(msg) func setCyclesCreate(newCycles: Nat) : async Bool {
        assert(msg.caller == owner);
        cyclesCreateCanvas := newCycles;
        return true;
    };

    public query func getCyclesCreate() : async Nat {
        cyclesCreateCanvas
    };

    public shared(msg) func setOwner(newOwner: Principal) : async Bool {
        assert(msg.caller == owner);
        owner := newOwner;
        return true;
    };

    public query func getOwner() : async Principal {
        owner
    };

    public shared(msg) func setCreateFeeTo(newFeeTo: Principal) : async Bool {
        assert(msg.caller == owner);
        createFeeTo := newFeeTo;
        return true;
    };

    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    public query func getSettings() : async FactorySettings {
        {
            maxSupply = factorySettings.maxSupply;
            maxForkRoyaltyRatio = factorySettings.maxForkRoyaltyRatio;
            maxForkFee = factorySettings.maxForkFee;
            maxNameSize = factorySettings.maxNameSize;
            maxDescSize = factorySettings.maxDescSize;
            maxCategorySize = factorySettings.maxCategorySize;
            createFee = factorySettings.createFee;
        }
    };

    private func _setController(canisterId: Principal): async () {

        let controllers: ?[Principal] = ?[owner, Principal.fromActor(this)];
        let settings: IC0.CanisterSettings = {
            controllers = controllers;
            compute_allocation = null;
            memory_allocation = null;
            freezing_threshold = null;
        };
        let params: IC0.UpdateSettingsParams = {
            canister_id = canisterId;
            settings = settings;
        };
        await IC0.IC.update_settings(params);
    };

}