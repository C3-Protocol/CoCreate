/**
 * Module     : NFT.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import WICP "../common/WICP";
import Types "../common/types";
import IC0 "../common/IC0";
import NFTTypes "../common/nftTypes";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";

shared(msg)  actor class NFT (paramInfo: Types.CollectionParamInfo, owner_: Principal,
                              cccOwner_:Principal, feeTo_: Principal, wicpCid_: Principal, bPublic_: Bool) = this {

    type ContentInfo = Types.ContentInfo;
    type Operation = Types.Operation;
    type NewItem = Types.NewItem;
    type NewIPFSItem = Types.NewIPFSItem;
    type AttrStru = Types.AttrStru;
    type TokenDetails = Types.TokenDetails;

    type ComponentAttribute = Types.ComponentAttribute;
    type NFTMetaData = Types.NFTMetaData;
    type GetTokenResponse = Types.GetTokenResponse;

    type WICPActor = WICP.WICPActor;
    type TokenIndex = Types.TokenIndex;
    type Balance = Types.Balance;
    type MintError = Types.MintError;
    type MintResponse = Types.MintResponse;
    type TransferResponse = Types.TransferResponse;
    type ListRequest = Types.ListRequest;
    type ListResponse = Types.ListResponse;
    type BuyResponse = Types.BuyResponse;
    type Listings = Types.Listings;
    type SoldListings = Types.SoldListings;
    type OpRecord = Types.OpRecord;
    type SaleRecord = Types.SaleRecord;
    type BuyRequest = Types.BuyRequest;
    type CollectionSettingsMu = Types.CollectionSettingsMu;
    type CollectionSettings = Types.CollectionSettings;


    type HttpRequest = NFTTypes.HttpRequest;
    type HttpResponse = NFTTypes.HttpResponse;

    private stable var owner: Principal = owner_;
    private stable var controller: Principal = cccOwner_;
    private stable var feeTo: Principal = feeTo_;
    private stable var bPublic: Bool = bPublic_;
    //private stable var forkRoyaltyRatio: ?Nat = paramInfo.forkRoyaltyRatio;
    private stable var WICPCanisterActor: WICPActor = actor(Principal.toText(wicpCid_));
    //private stable var marketFeeRatio = 1;
    //private stable var newItemProtocolFee = 10_000_000;
    //private stable var newItemForkFee: ?Nat = paramInfo.forkFee;
    private stable var glIndex = 0;
    private stable var attrIndex = 0;
    //private stable var totalSupply = paramInfo.totalSupply; 
    private stable var collectionSettings: CollectionSettingsMu = Types.COLLECTION_SETTINGS;
    collectionSettings.forkRoyaltyRatio := paramInfo.forkRoyaltyRatio;
    collectionSettings.newItemForkFee := paramInfo.forkFee;
    collectionSettings.totalSupply := paramInfo.totalSupply;



    private stable var contentInfo: ContentInfo = paramInfo.contentInfo;
    private stable var logo: Blob = switch(paramInfo.logo){
        case (?b) {b};
        case _ {Blob.fromArray([])};
    };
    private stable var featured: Blob = switch(paramInfo.featured){
        case (?b) {b};
        case _ {Blob.fromArray([])};
    };
    private stable var banner: Blob = switch(paramInfo.banner){
        case (?b) {b};
        case _ {Blob.fromArray([])};
    };

    type ListRecord = List.List<OpRecord>;
    private stable var opsEntries: [(TokenIndex, [OpRecord])] = [];
    private var ops = HashMap.HashMap<TokenIndex, ListRecord>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var allSaleRecord: List.List<SaleRecord> = List.nil<SaleRecord>();

    private stable var orignData: [var Blob] = Array.init<Blob>(3, Blob.fromArray([]));
    private stable var thumbnailData: [var Blob] = Array.init<Blob>(3, Blob.fromArray([]));
 
    private stable var componentsEntries : [(TokenIndex, ComponentAttribute)] = [];
    private var components = HashMap.HashMap<TokenIndex, ComponentAttribute>(1, Types.TokenIndex.equal, Types.TokenIndex.hash); 

    private stable var componentsRevEntries : [(ComponentAttribute, TokenIndex)] = [];
    private var componentsRev = HashMap.HashMap<ComponentAttribute, TokenIndex>(1, Types.ComponentAttribute.equal, Types.ComponentAttribute.hash); 

    private stable var tokensEntries : [(TokenIndex, NFTMetaData)] = [];
    private var tokens = HashMap.HashMap<TokenIndex, NFTMetaData>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var listingsEntries : [(TokenIndex, Listings)] = [];
    private var listings = HashMap.HashMap<TokenIndex, Listings>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var soldListingsEntries : [(TokenIndex, SoldListings)] = [];
    private var soldListings = HashMap.HashMap<TokenIndex, SoldListings>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    // Mapping from NFT canister ID to owner
    private stable var ownersEntries : [(TokenIndex, Principal)] = [];
    private var owners = HashMap.HashMap<TokenIndex, Principal>(1, Types.TokenIndex.equal, Types.TokenIndex.hash); 

    private var nftApprovals = HashMap.HashMap<TokenIndex, Principal>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);
    // Mapping from owner to operator approvals
    private var operatorApprovals = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Bool>>(1, Principal.equal, Principal.hash);
    
    private stable var ipfsLinkEntries: [(Text,Text) ] = [];
    private var ipfsLink = HashMap.HashMap<Text, Text>(1, Text.equal, Text.hash);

    system func preupgrade() {
        componentsEntries := Iter.toArray(components.entries());
        componentsRevEntries := Iter.toArray(componentsRev.entries());
        tokensEntries := Iter.toArray(tokens.entries());

        listingsEntries := Iter.toArray(listings.entries());
        soldListingsEntries := Iter.toArray(soldListings.entries());
        ownersEntries := Iter.toArray(owners.entries());
        ipfsLinkEntries := Iter.toArray(ipfsLink.entries());

        var size0 : Nat = ops.size();
        var temp0 : [var (TokenIndex, [OpRecord])] = Array.init<(TokenIndex, [OpRecord])>(size0, (0, []));
        size0 := 0;
        for ((k, v) in ops.entries()) {
            temp0[size0] := (k, List.toArray(v));
            size0 += 1;
        };
        opsEntries := Array.freeze(temp0);
    };

    system func postupgrade() {
        owners := HashMap.fromIter<TokenIndex, Principal>(ownersEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        listings := HashMap.fromIter<TokenIndex, Listings>(listingsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        soldListings := HashMap.fromIter<TokenIndex, SoldListings>(soldListingsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        tokens := HashMap.fromIter<TokenIndex, NFTMetaData>(tokensEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        components := HashMap.fromIter<TokenIndex, ComponentAttribute>(componentsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        componentsRev := HashMap.fromIter<ComponentAttribute, TokenIndex>(componentsRevEntries.vals(), 1, Types.ComponentAttribute.equal, Types.ComponentAttribute.hash);
        ipfsLink := HashMap.fromIter<Text, Text>(ipfsLinkEntries.vals(), 1, Text.equal, Text.hash);

        tokensEntries := [];
        listingsEntries := [];
        soldListingsEntries := [];
        ownersEntries := [];
        ipfsLinkEntries := [];

        for ((k, v) in opsEntries.vals()) {
            ops.put(k, List.fromArray<OpRecord>(v));
        };
        opsEntries := [];
    };

    public query func getTokenById(tokenId:Nat): async GetTokenResponse{
        let token = switch(tokens.get(tokenId)){
            case (?t){t};
            case _ {return #err(#NotFoundIndex);};
        };

        var comAttr : List.List<ComponentAttribute> = List.nil<ComponentAttribute>();

        for(id in token.attrIds.vals()){
            switch(components.get(id)){
                case(?a){ 
                    comAttr := List.push(a, comAttr);
                };
                case _ { return #err(#NotFoundIndex); };
            }
        };

        let tokenDetail : TokenDetails = {
                id = tokenId;
                attrArr = List.toArray(comAttr);
        };
        #ok(tokenDetail)
    };

    public shared(msg) func setFavorite(tokenIndex: TokenIndex): async Bool {
        return true;
    };

    public shared(msg) func cancelFavorite(tokenIndex: TokenIndex): async Bool {
        return true;
    };

    private func _addRecord(index: TokenIndex, op: Operation, from: ?Principal, to: ?Principal, 
        price: ?Nat, timestamp: Time.Time
    ) {
        let o : OpRecord = {
            op = op;
            from = from;
            to = to;
            price = price;
            timestamp = timestamp;
        };
        switch (ops.get(index)) {
            case (?l) {
                let newl = List.push<OpRecord>(o, l);
                ops.put(index, newl);
            };
            case (_) {
                let l1 = List.nil<OpRecord>();
                let l2 = List.push<OpRecord>(o, l1);
                ops.put(index, l2);
            };   
        };
    };

    private func _addSaleRecord(index: TokenIndex, from: ?Principal, to: ?Principal, 
        price: ?Nat, timestamp: Time.Time
    ) {
        var linkInfo = tokens.get(index);
        let saleRecord : SaleRecord = {
            tokenIndex = index;
            from = from;
            to = to;
            price = price;
            photoLink = switch(linkInfo) {
                case (?l){l.photoLink};
                case _ {null};
            };
            videoLink = switch(linkInfo) {
                case (?l){l.videoLink};
                case _ {null};
            };
            timestamp = timestamp;
        };
        allSaleRecord := List.push(saleRecord, allSaleRecord);
    };

    public shared(msg) func uploadICItem(newItem: NewItem) : async MintResponse {
        if(owner != msg.caller and (not bPublic) ){ return #err(#NotOwner); };
        if(newItem.name.size() > 20 or newItem.desc.size() > 2000){
                return #err(#ParamError);
        };
        
        let transferResult = await WICPCanisterActor.transferFrom(msg.caller, feeTo, collectionSettings.uploadProtocolBaseFee);
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        }; 

        let index = glIndex;
        orignData[glIndex] := newItem.orignData;
        switch(newItem.thumbnailData){
            case(?data){thumbnailData[glIndex] := data;};
            case _ {};
        };

        var comIndexArr = Buffer.Buffer<Nat>(0);
        for(attr in newItem.attrArr.vals()){
            switch(componentsRev.get(attr)){
                case (?i){comIndexArr.add(i)};
                case _ {
                    componentsRev.put(attr, attrIndex);
                    components.put(attrIndex, attr);
                    comIndexArr.add(attrIndex);
                    attrIndex += 1;
                };
            };
        };
        let data: NFTMetaData = {
            parentToken = newItem.parentToken;
            index = glIndex;
            name = newItem.name;
            desc = newItem.desc;
            photoLink = null;
            videoLink = null;
            royaltyRatio = newItem.earnings;
            royaltyFeeTo = newItem.royaltyFeeTo;
            attrIds = comIndexArr.toArray();
        };
        tokens.put(glIndex, data);

        owners.put(glIndex, msg.caller);
        _addRecord(glIndex, #Mint, null, ?msg.caller, null, Time.now());
        glIndex += 1;

        return #ok(index);
    };

    public shared(msg) func uploadIPFSItem(newItem: NewIPFSItem) : async MintResponse {
        if(owner != msg.caller and tokens.size() == 0){ 
            return #err(#NotOwner);
        };

        //todo：tmp use other and should be NotPublicOrFork
        if (not bPublic and Option.isNull(collectionSettings.newItemForkFee)){
            return #err(#Other);
        };
        
        if(owners.size() == collectionSettings.totalSupply) {return #err(#SupplyUsedUp);};
       
        let (videoLink,photoLink) = switch ((newItem.videoLink,newItem.photoLink)) {
            case (?video,?photo) {
                (video,photo)
            };
            case _ {
                return #err(#NoIPFSLink);
            }
        };

        switch(_checkIPFSItemParam(newItem,videoLink,photoLink)){
            case(#ok(_)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };

        var tos = Buffer.Buffer<Principal>(0);
        var values = Buffer.Buffer<Nat>(0);

        switch (collectionSettings.newItemForkFee) {
            case(?fee){
                tos.add(owner);
                values.add(fee);
                let protocolDynamicFee:Nat = Nat.div(Nat.mul(fee, collectionSettings.uploadProtocolFeeRatio), 100);
                tos.add(feeTo);
                values.add(collectionSettings.uploadProtocolBaseFee + protocolDynamicFee);
            };
            case _ {
                tos.add(feeTo);
                values.add(collectionSettings.uploadProtocolBaseFee);
            };
        };
        let transferResult = await WICPCanisterActor.batchTransferFrom(msg.caller, tos.toArray(), values.toArray());
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };

        var comIndexArr = Buffer.Buffer<Nat>(0);
        for(attr in newItem.attrArr.vals()){
            switch(componentsRev.get(attr)){
                case (?i){comIndexArr.add(i)};
                case _ {
                    componentsRev.put(attr, attrIndex);
                    components.put(attrIndex, attr);
                    comIndexArr.add(attrIndex);
                    attrIndex += 1;
                };
            };
        };

        let data: NFTMetaData = {
            parentToken = newItem.parentToken;
            index = glIndex;
            name = newItem.name;
            desc = newItem.desc;
            photoLink = newItem.photoLink;
            videoLink = newItem.videoLink;
            royaltyRatio = newItem.earnings;
            royaltyFeeTo = newItem.royaltyFeeTo;
            attrIds = comIndexArr.toArray();
        };
        tokens.put(glIndex, data);

        ipfsLink.put(videoLink,photoLink);

        let index = glIndex;
        owners.put(glIndex, msg.caller);
        _addRecord(glIndex, #Mint, null, ?msg.caller, null, Time.now());

        glIndex += 1;

        return #ok(index);
    };

    public shared(msg) func transferFrom(from: Principal, to: Principal, tokenIndex: TokenIndex): async TransferResponse {
        if(Option.isSome(listings.get(tokenIndex))){
            return #err(#ListOnMarketPlace);
        };
        if( not _isApprovedOrOwner(from, msg.caller, tokenIndex) ){
            return #err(#NotOwnerOrNotApprove);
        };
        if(from == to){
            return #err(#NotAllowTransferToSelf);
        };
        _transfer(from, to, tokenIndex);
        if(Option.isSome(listings.get(tokenIndex))){
            listings.delete(tokenIndex);
        };
        _addRecord(tokenIndex, #Transfer, ?from, ?to, null, Time.now());
        _addSaleRecord(tokenIndex, ?from, ?to, null, Time.now());
        return #ok(tokenIndex);
    };

    public shared(msg) func batchTransferFrom(from: Principal, tos: [Principal], tokenIndexs: [TokenIndex]): async TransferResponse {
        if(tokenIndexs.size() == 0 or tos.size() == 0
            or tokenIndexs.size() != tos.size()){
            return #err(#Other);
        };
        for(v in tokenIndexs.vals()){
            if(Option.isSome(listings.get(v))){
                return #err(#ListOnMarketPlace);
            };
            if( not _isApprovedOrOwner(from, msg.caller, v) ){
                return #err(#NotOwnerOrNotApprove);
            };
        };
        for(i in Iter.range(0, tokenIndexs.size() - 1)){
            _transfer(from, tos[i], tokenIndexs[i]);
        };
        return #ok(tokenIndexs[0]);
    };

    public shared(msg) func approve(approve: Principal, tokenIndex: TokenIndex): async Bool{
        let ow = switch(_ownerOf(tokenIndex)){
            case(?o){o};
            case _ {return false;};
        };
        if(ow != msg.caller){return false;};
        nftApprovals.put(tokenIndex, approve);
        return true;
    };

    public shared(msg) func setApprovalForAll(operatored: Principal, approved: Bool): async Bool{
        assert(msg.caller != operatored);
        switch(operatorApprovals.get(msg.caller)){
            case(?op){
                op.put(operatored, approved);
                operatorApprovals.put(msg.caller, op);
            };
            case _ {
                var temp = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);
                temp.put(operatored, approved);
                operatorApprovals.put(msg.caller, temp);
            };
        };
        return true;
    };

    public shared(msg) func list(listReq: ListRequest): async ListResponse {
        if(Option.isSome(listings.get(listReq.tokenIndex))){
            return #err(#AlreadyList);
        };
        if(not _checkOwner(listReq.tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        let timeStamp = Time.now();
        var order:Listings = {
            tokenIndex = listReq.tokenIndex; 
            seller = msg.caller; 
            price = listReq.price;
            time = timeStamp;
        };
        listings.put(listReq.tokenIndex, order);
        _addRecord(listReq.tokenIndex, #List, ?msg.caller, null, ?listReq.price, timeStamp);
        return #ok(listReq.tokenIndex);
    };

    public shared(msg) func updateList(listReq: ListRequest): async ListResponse {
        let orderInfo = switch(listings.get(listReq.tokenIndex)){
            case (?o){o};
            case _ {return #err(#NotFoundIndex);};
        };
        if(listReq.price == orderInfo.price){
            return #err(#SamePrice);
        };
        if(not _checkOwner(listReq.tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        let timeStamp = Time.now();
        var order:Listings = {
            tokenIndex = listReq.tokenIndex; 
            seller = msg.caller; 
            price = listReq.price;
            time = timeStamp;
        };
        listings.put(listReq.tokenIndex, order);
        _addRecord(listReq.tokenIndex, #UpdateList, ?msg.caller, null, ?listReq.price, timeStamp);
        return #ok(listReq.tokenIndex);
    };

    public shared(msg) func cancelList(tokenIndex: TokenIndex): async ListResponse {
        let orderInfo = switch(listings.get(tokenIndex)){
            case (?o){o};
            case _ {return #err(#NotFoundIndex);};
        };
        
        if(not _checkOwner(tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        var price: Nat = orderInfo.price;
        listings.delete(tokenIndex);
        _addRecord(tokenIndex, #CancelList, ?msg.caller, null, ?price, Time.now());
        return #ok(tokenIndex);
    };

    public shared(msg) func buyNow(buyRequest: BuyRequest): async BuyResponse {
        assert(buyRequest.marketFeeRatio == collectionSettings.marketFeeRatio);
        let orderInfo = switch(listings.get(buyRequest.tokenIndex)){
            case (?l){l};
            case _ {return #err(#NotFoundIndex);};
        };
        if(msg.caller == orderInfo.seller){
            return #err(#NotAllowBuySelf);
        };
        
        if(buyRequest.price < orderInfo.price){
            return #err(#Other);
        };
        
        if(not _checkOwner(buyRequest.tokenIndex, orderInfo.seller)){
            listings.delete(buyRequest.tokenIndex);
            return #err(#AlreadyTransferToOther);
        };

        var tos = Buffer.Buffer<Principal>(0);
        var values = Buffer.Buffer<Nat>(0);

        var royaltyRatio:Nat = 0;
        var royaltyFeeTo:Principal = owner;
        switch(tokens.get(buyRequest.tokenIndex)){
            case(?info){
                royaltyRatio := info.royaltyRatio;
                royaltyFeeTo := info.royaltyFeeTo;
            };
            case _ {return #err(#Other);};
        };

        // fee inclued marketFee,royaltyFee,forkRoyaltyFee
        let marketFee:Nat = Nat.div(Nat.mul(orderInfo.price, buyRequest.marketFeeRatio), 100);
        let royaltyFee:Nat = Nat.div(Nat.mul(orderInfo.price, royaltyRatio), 100);
        var value = orderInfo.price - marketFee - royaltyFee;
        switch (collectionSettings.forkRoyaltyRatio) {
            case(?ratio){
                let forkRoyaltyFee:Nat = Nat.div(Nat.mul(orderInfo.price, ratio), 100);
                value := value - forkRoyaltyFee;
                tos.add(owner);
                values.add(forkRoyaltyFee);
            };
            case _ {};
        };

        tos.add(buyRequest.feeTo);
        values.add(marketFee);

        //no royaltyFee if seller is collection owner
        if (royaltyFeeTo == orderInfo.seller){
            tos.add(royaltyFeeTo);
            values.add(royaltyFee + value);
        }else{
            tos.add(royaltyFeeTo);
            tos.add(orderInfo.seller);
            values.add(royaltyFee);
            values.add(value);
        };

        let transferResult = await WICPCanisterActor.batchTransferFrom(msg.caller, tos.toArray(), values.toArray());
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };
        listings.delete(buyRequest.tokenIndex);

        _transfer(orderInfo.seller, msg.caller, orderInfo.tokenIndex);
        _addSoldListings(orderInfo);
        _addRecord(buyRequest.tokenIndex, #Sale, ?orderInfo.seller, ?msg.caller, ?orderInfo.price, Time.now());
        _addSaleRecord(buyRequest.tokenIndex, ?orderInfo.seller, ?msg.caller, ?orderInfo.price, Time.now());
        
        return #ok(buyRequest.tokenIndex);
    };

    public shared(msg) func setMaxMarketFeeRatio(newFeeRatio: Nat) : async Bool {
        assert(msg.caller == controller);
        collectionSettings.marketFeeRatio := newFeeRatio;
        return true;
    };

    public query func getAllSaleRecord(): async [SaleRecord] {
        List.toArray(allSaleRecord)
    };

    public query func getSaleRecordByAccount(user: Principal): async [SaleRecord] {
        var ret: List.List<SaleRecord> = List.nil<SaleRecord>();
        let saleArr: [SaleRecord] = List.toArray(allSaleRecord);
        for(val in saleArr.vals()){
            switch(val.from, val.to){
                case (?f, ?t) {
                    if(f == user or t == user){ ret := List.push(val, ret); };
                };
                case (_, _) {};
            };
        };
        List.toArray(ret)
    };

    public query func getFeeTo() : async Principal {
        feeTo
    };
    
    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getHistory(index: TokenIndex) : async [OpRecord] {
        var ret: [OpRecord] = [];
        switch (ops.get(index)) {
            case (?l) {
                ret := List.toArray(l);
            };
            case (_) {};   
        };
        return ret;
    };

    public query func getListings() : async [(NFTMetaData, Listings)] {
        var ret = Buffer.Buffer<(NFTMetaData, Listings)>(listings.size());
        for((k,v) in listings.entries()){
            switch(tokens.get(k)){
                case(?d){ret.add((d, v));};
                case _ {};
            }
        };
        return ret.toArray();
    };

    public query func getNFTMetaDataByIndex(index: TokenIndex) : async ?NFTMetaData {
        tokens.get(index)
    };

    public query func getListingsByAttr(attrArr: [AttrStru]) : async [(NFTMetaData, Listings)] {
        var ret = Buffer.Buffer<(NFTMetaData, Listings)>(listings.size());
        for((k,v) in listings.entries()){
            if(_checkComAttr(k, attrArr)){
                switch(tokens.get(k)){
                    case(?d){ret.add((d, v));};
                    case _ {};
                }
            };
        };
        return ret.toArray();
    };

    private func _checkIPFSItemParam(newItem: NewIPFSItem,videoLink: Text,photoLink: Text) : Result.Result<(), MintError> {
        switch (ipfsLink.get(videoLink)) {
            case(?_photoLink){
                //Be regarded as exist,no matter the _photoLink are the same or not
                return #err(#IPFSLinkAlreadyExist);
            };
            case _ {};
        };
        if(newItem.attrArr.size() > collectionSettings.maxAttrNum){return #err(#TooManyAttr);};

        if(newItem.name.size() > collectionSettings.maxNameSize 
            or newItem.desc.size() > collectionSettings.maxDescSize 
            or Option.isNull(newItem.photoLink)
        ){
            return #err(#ParamError);
        };

        if(newItem.earnings > collectionSettings.maxRoyaltyRatio){
            return #err(#ParamError);
        };
        #ok()
    };

    private func _checkComAttr(index: TokenIndex, attrArr: [AttrStru]) : Bool {

        let token = switch(tokens.get(index)){
            case (?t){t};
            case _ {return false;};
        };
        var attrMap = HashMap.HashMap<Nat, Bool>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        for(id in token.attrIds.vals()){
            attrMap.put(id,true);
        };

        for(attrStru in attrArr.vals()){
            var oneAttr = false;
            for(id in attrStru.attrIds.vals()){
                switch(attrMap.get(id)){
                    case (?b){ oneAttr := true; };
                    case _ {};
                }
            };
            if(not oneAttr){return false;};
        };
        return true;
    };

    public query func getSoldListings() : async [(NFTMetaData, SoldListings)] {
        var ret = Buffer.Buffer<(NFTMetaData, SoldListings)>(soldListings.size());
        for((k,v) in soldListings.entries()){
            switch(tokens.get(k)){
                case(?d){ret.add((d, v));};
                case _ {};
            }
        };
        return ret.toArray();
    };

    public query func isList(index: TokenIndex) : async ?Listings {
        listings.get(index)
    };

    public query func getApproved(tokenIndex: TokenIndex) : async ?Principal {
        nftApprovals.get(tokenIndex)
    };

    public query func isApprovedForAll(owner: Principal, operatored: Principal) : async Bool {
        _checkApprovedForAll(owner, operatored)
    };

    public query func ownerOf(tokenIndex: TokenIndex) : async ?Principal {
        _ownerOf(tokenIndex)
    };

    public query func balanceOf(user: Principal) : async Nat {
        var ret: Nat = 0;
        for( (k,v) in owners.entries() ){
            if(v == user){ ret += 1; };
        };
        ret
    };

    public query func getCycles() : async Nat {
        return Cycles.balance();
    };
    
    public query func isPublic() : async Bool {
        bPublic
    };

    public shared(msg) func setbPublic(isPublic: Bool) : async Bool {
        assert(msg.caller == controller);
        bPublic := isPublic;
        return true;
    };

    public shared(msg) func setMAXRoyaltyRatio(maxRatio: Nat) : async Bool {
        assert(msg.caller == controller);
        collectionSettings.maxRoyaltyRatio := maxRatio;
        return true;
    };

    public query func getSettings() : async CollectionSettings {
        //fixme: 规避不能返回包含var的结构体的问题
        {
            maxRoyaltyRatio = collectionSettings.maxRoyaltyRatio; 
            maxNameSize = collectionSettings.maxNameSize; 
            maxDescSize = collectionSettings.maxDescSize; 
            maxCategorySize = collectionSettings.maxCategorySize;
            maxAttrNum = collectionSettings.maxAttrNum;  
            uploadProtocolBaseFee = collectionSettings.uploadProtocolBaseFee;
            uploadProtocolFeeRatio = collectionSettings.uploadProtocolFeeRatio;
            marketFeeRatio = collectionSettings.marketFeeRatio;
            forkRoyaltyRatio = collectionSettings.forkRoyaltyRatio;
            newItemForkFee = collectionSettings.newItemForkFee;
            totalSupply = collectionSettings.totalSupply;
        }
    };

    public shared(msg) func setItemBaseFee(fee: Nat) : async Bool {
        assert(msg.caller == controller);
        collectionSettings.uploadProtocolBaseFee := fee;
        return true;
    };

    public query func getCollectionInfo() : async ContentInfo {
        contentInfo
    };

    // get all token by pid
    public query func getAllNFT(user: Principal) : async [NFTMetaData] {
        var ret = Buffer.Buffer<NFTMetaData>(0);
        for((k,v) in owners.entries()){
            if(v == user){
                switch(tokens.get(k)){
                    case(?d){ret.add(d);};
                    case _ {};
                }
            };
        };
        Array.sort(ret.toArray(), func (x : NFTMetaData, y : NFTMetaData) : { #less; #equal; #greater } {
            if (x.index < y.index) { #less }
            else if (x.index == y.index) { #equal }
            else { #greater }
        })
    };

    //get all token 
    public query func getAllToken() : async [(NFTMetaData, ?Listings)] {
        var ret = Buffer.Buffer<(NFTMetaData, ?Listings)>(listings.size());
        for((k,v) in tokens.entries()){
            ret.add((v, listings.get(k)));
        };
        Array.sort(ret.toArray(), func (x : (NFTMetaData, ?Listings), y : (NFTMetaData, ?Listings)) : { #less; #equal; #greater } {
            if (x.0.index < y.0.index) { #less }
            else if (x.0.index == y.0.index) { #equal }
            else { #greater }
        })
    };

    public shared query(msg) func getAll() : async [(TokenIndex, Principal)] {
        assert(msg.caller == controller);
        Iter.toArray(owners.entries())
    };

    public query func getCurrentSupply() : async Nat {
        owners.size()
    };

    public query func getCirculation() : async Nat {
        owners.size()
    };

    public query func getOwnerSize() : async Nat {
        var holders = HashMap.HashMap<Principal, Bool>(0, Principal.equal, Principal.hash);
        for((k,v) in owners.entries()){
            if(Option.isNull(holders.get(v))){
                holders.put(v, true);
            };
        };
        holders.size()
    };

    public query func http_request(request: HttpRequest) : async HttpResponse {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() != 2){
            assert(false);
        };

        var nftData :Blob = Blob.fromArray([]);
        if(path[0] == "token") {
            if(path[1] == "logo"){
                nftData := logo;
            }else if(path[1] == "featured"){
                nftData := featured;
            }else if(path[1] == "banner"){
                nftData := banner;
            }else{
                let tokenId = NFTTypes.textToNat(path[1]);
                if(tokenId > 1000){
                    assert(false);
                };
                nftData := orignData[tokenId];
            };
        }else if (path[0] == "thumbnail") {
            let tokenId = NFTTypes.textToNat(path[1]);
            if(tokenId > 1000){
                assert(false);
            };
            nftData := thumbnailData[tokenId];
        }else{assert(false)};

        return {
                body = nftData;
                headers = [("Content-Type", "image/png")];
                status_code = 200;
                streaming_strategy = null;
        };
    };

    private func _transfer(from: Principal, to: Principal, tokenIndex: TokenIndex) {
        nftApprovals.delete(tokenIndex);
        owners.put(tokenIndex, to);
    };

    private func _addSoldListings( orderInfo :Listings) {
        switch(soldListings.get(orderInfo.tokenIndex)){
            case (?sold){
                let newDeal = {
                    lastPrice = orderInfo.price;
                    time = Time.now();
                    account = sold.account + 1;
                };
                soldListings.put(orderInfo.tokenIndex, newDeal);
            };
            case _ {
                let newDeal = {
                    lastPrice = orderInfo.price;
                    time = Time.now();
                    account = 1;
                };
                soldListings.put(orderInfo.tokenIndex, newDeal);
            };
        };
    };

    private func _ownerOf(tokenIndex: TokenIndex) : ?Principal {
        owners.get(tokenIndex)
    };

    private func _checkOwner(tokenIndex: TokenIndex, from: Principal) : Bool {
        switch(owners.get(tokenIndex)){
            case (?o){
                if(o == from){
                    true
                }else{
                    false
                }
            };
            case _ {false};
        }
    };

    private func _checkApprove(tokenIndex: TokenIndex, approved: Principal) : Bool {
        switch(nftApprovals.get(tokenIndex)){
            case (?o){
                if(o == approved){
                    true
                }else{
                    false
                }
            };
            case _ {false};
        }
    };

    private func _checkApprovedForAll(owner: Principal, operatored: Principal) : Bool {
        switch(operatorApprovals.get(owner)){
            case (?a){
                switch(a.get(operatored)){
                    case (?b){b};
                    case _ {false};
                }
            };
            case _ {false};
        }
    };

    private func _isApprovedOrOwner(from: Principal, spender: Principal, tokenIndex: TokenIndex) : Bool {
        _checkOwner(tokenIndex, from) and (_checkOwner(tokenIndex, spender) or 
        _checkApprove(tokenIndex, spender) or _checkApprovedForAll(from, spender))
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