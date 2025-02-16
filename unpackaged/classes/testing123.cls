/**************************************************************************************************
(c) 2018 Appirio, Inc.
Name of the Trigger: ACS_OpportunityTriggerHelper
Description : Generic Trigger that handles all events & pass values to Trigger Helper.
Created by : Jason Carmer | Date : 7-11-2018
Trigger Type : Original
Task : T-710604 | Story : S-502160
Modified by: Erin McGee | 05/21/2019 | 80520 | Depreciate Code 
Modified by: Asif Baksh | 08/14/2019 | 82916 | Update payslip email send (see 82916 - Asif B for further details) 
Modified by : Mike DeMeglio | Feb 5, 2020 | PDI-94306 | Update the Society Key for an Opp only when it has been added or changed on the Opp, any other updates to the Opp should not fire the key update code. 
Modified by : Nicole Bock | Mar 4, 2020 | PDI-98953 | Delete newly created payments and revert changes on existing payments when opportunity is unlinked
Modified by : Bhargav Esotiya | May 23, 2020 | Resolving Invalid id error in afterLinkingOrUnlikingOpportunity method
Modified by : MJ Bean | May 5, 2023 | Adding Account Plan logic.
Modified by : Roshan Ghosalkar |9/26/24 
**************************************************************************************************/

public class ACS_OpportunityTriggerHelper {
    //PBI - 295357(Huron), creating static variable for by passing closed won validation(white list fields).....
    public static Boolean bypassClosedOppVal = false;
    public static Boolean isProcessChargeback = false;

    public static map<string, npe01__Payment_Field_Mapping_Settings__c> paymentMappings {
        get {
            if (paymentMappings == null) {
                
                map<string, npe01__Payment_Field_Mapping_Settings__c> paymentMappingsAll = npe01__Payment_Field_Mapping_Settings__c.getAll();
                paymentMappings = npe01__Payment_Field_Mapping_Settings__c.getAll().clone();
                
                for (string s : paymentMappingsAll.keySet()) {
                    npe01__Payment_Field_Mapping_Settings__c pfms = paymentMappingsAll.get(s);
                    
                    SobjectField opportunityField;
                    SobjectField paymentField;
                    boolean isValid = true;
                                       
                    opportunityField = Schema.sObjectType.Opportunity.fields.getMap().get(pfms.npe01__Opportunity_Field__c);
                    paymentField = Schema.sObjectType.npe01__OppPayment__c.fields.getMap().get(pfms.npe01__Payment_Field__c);
                    
                    if (paymentField != null && opportunityField != null) {
                        Schema.DisplayType payF = paymentField.getDescribe().getType();
                        Schema.DisplayType oppF = opportunityField.getDescribe().getType();
                        isValid = canDisplaytypesCopy(oppF, payF);
                    } else {
                        isValid = false;
                    }
                    
                    if (isValid == false) paymentMappings.keyset().remove(s);
                }
                
            }
            return paymentMappings;
        }
        set;
    }
    public static set<string> setOppTypeNoPayment {
        get {
            if (setOppTypeNoPayment == null) {
                string strProp = getContactsSettings().npsp__Opp_Types_Excluded_for_Payments__c;
                if (strProp != null) {
                    setOppTypeNoPayment = new set<string> (strProp.split(';'));
                } else {
                    setOppTypeNoPayment = new set<string> ();
                }
            }
            return setOppTypeNoPayment;
        }
        set;
    }
    
    public static set<id> setOppRecordTypeIdNoPayment {
        get {
            if (setOppRecordTypeIdNoPayment == null) {
                string strProp = getContactsSettings().npsp__Opp_RecTypes_Excluded_for_Payments__c;
                if (strProp != null) {
                    setOppRecordTypeIdNoPayment = new Set<Id> ((List<Id>) strProp.split(';'));
                } else {
                    setOppRecordTypeIdNoPayment = new set<Id> ();
                }
            }
            return setOppRecordTypeIdNoPayment;
        }
        set;
    }
    private static final SObjectField OppCurrencyField = Schema.sObjectType.Opportunity.fields.getMap().get('CurrencyIsoCode');
    private static final SObjectField PaymentCurrencyField = Schema.sObjectType.npe01__OppPayment__c.fields.getMap().get('CurrencyIsoCode');
    
    public static void fetchSocietyKeyAndValues(List<Opportunity> newList, Map<id,Opportunity> oldMap){
        
        Set<String> keys = new Set<String>();
             
        Set<Id> skc = new Set<Id>();
        Map<Id, Society_Key_Cache__c> skcMap = new Map<Id, Society_Key_Cache__c>();
        for(Opportunity opp : newList){
            if (opp.acs_Society_Key_Cache__c != null){
                skc.add(opp.acs_Society_Key_Cache__c);
            }
        }
        for (Society_Key_Cache__c ck : [SELECT Id, Name, Department__c, Product_Instance__c, Region__c, Subsidiary__c, Fund__c, Association__c, Active__c, acs_needsLookup__c, acs_isNotFound__c
                                        FROM Society_Key_Cache__c WHERE Id in :skc])
        {
            skcMap.put(ck.Id, ck);
        }
               
        for(Opportunity opp : newList){
            
            String originalKeyVal = opp.acs_Society_Key_Cache__c;
                        
            if ((opp.acs_Society_Key_Cache__c != null && oldMap == null) || 
                (oldMap != null && oldMap.get(opp.Id) != null && (
                    (opp.acs_Society_Key_Cache__c == null && oldMap.get(opp.Id).acs_Society_Key_Cache__c != null) || (opp.acs_Society_Key_Cache__c != oldMap.get(opp.Id).acs_Society_Key_Cache__c)) )){
                        if (opp.acs_Society_Key_Cache__c == null || skcMap.get(opp.acs_Society_Key_Cache__c).acs_isNotFound__c || skcMap.get(opp.acs_Society_Key_Cache__c).acs_needsLookup__c){
                            opp.acs_Society_Key__c = null;
                            opp.acs_Subsidiary__c = null;
                            opp.acs_Department__c = null;
                            opp.acs_Product_Instance__c = null;
                            opp.acs_Region__c = null;
                            opp.acs_Association__c = null;
                            
                            if (opp.acs_Society_Key_Cache__c == null){
                                opp.acs_Society_Key__c = '';
                            }
                            else {
                                opp.acs_Society_Key__c = skcMap.get(opp.acs_Society_Key_Cache__c).Name;
                            }
                        }
                        else{
                            opp.acs_Society_Key__c = skcMap.get(opp.acs_Society_Key_Cache__c).Name;
                        }
                    }
            
            Boolean keyFound = skcMap.containsKey(opp.acs_Society_Key_Cache__c);
            System.debug('KEY FOUND: ' + keyFound);
            Boolean keyActive = keyfound ? skcMap.get(opp.acs_Society_Key_Cache__c).Active__c : false;
            System.debug('KEY ACTIVE? ' + keyActive);
            Boolean isChanged = oldMap != null && (oldMap.get(opp.Id).acs_Society_Key_Cache__c != originalKeyVal);
            System.debug('KEY CHANGED? ' + isChanged);
            Boolean isInsert = oldMap == null;
            System.debug('INSERT? ' + isInsert);
                    
            if(isChanged || isInsert){
                System.debug('@@ Society Key has changed or record is new.');
                keys.add(opp.acs_Society_Key__c);
            } else { System.debug('@@ Payment society key will not be checked.'); }
        }
             
        if (keys.size() > 0) {
            Map<String, Society_Key_Cache__c> keyMap = ACS_SocietyKey.getSocietyKeyMap(keys);
            System.debug('@@ keyMap: ' + keyMap);
                   
            for(Opportunity opp : newList){
                        
                if (opp.acs_Society_Key__c != null){
                           
                    if(keyMap.containsKey(opp.acs_Society_Key__c)){
                        Society_Key_Cache__c sk = keyMap.get(opp.acs_Society_Key__c);
                        System.debug('@@ keyMap contains a key for ' + opp.acs_Society_Key__c + ', Active: ' + sk.Active__c + ', acs_isNotFound__c: '+ sk.acs_isNotFound__c);
                        
                        if(!sk.acs_isNotFound__c){
                            opp.acs_Society_Key_Cache__c = sk.Id;
                            opp.acs_Society_Key__c = sk.Name;
                            opp.acs_Subsidiary__c = sk.Subsidiary__c;
                            opp.acs_Department__c = sk.Department__c;
                            opp.acs_Product_Instance__c = sk.Product_Instance__c;
                            opp.acs_Region__c = sk.Region__c;
                            opp.acs_Association__c = sk.Association__c;
                                                        
                            if(opp.acs_Fund__c == null){                                
                                opp.acs_Fund__c = sk.Fund__c;
                            }
                        }
                    }
                    
                }
            }
        }
    }
    
    public static void onOppClosedWon_SK_Blank(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {  
        Map<Id, Opportunity> OppIdMap = new Map<Id, Opportunity>();
        
        for(Opportunity opp : newList) {
            if(opp.RecordTypeId == Constants_ACS.RECORDTYPE_OPPTY_MANAGED
               && opp.StageName == 'Closed Won' && opp.StageName != oldMap.get(opp.Id).StageName
               && opp.acs_Ask_Type__c != 'Quantity') {
                   if(!opp.acs_Modified__c) {
                       if(String.isNotBlank(opp.acs_Society_Key_Cache__c) && String.isNotBlank(opp.acs_Fund__c)
                          && String.isNotBlank(opp.acs_Revenue_Category__c) && String.isNotBlank(opp.acs_Event_Year__c)) {
                              OppIdMap.put(opp.Id, opp);
                          } 
                       else {
                           opp.addError(Label.ACS_Opp_SK_ClosedWon + '1');
                       }	
                   }
               }
        }
        
        if(!OppIdMap.isEmpty()) {
            for(npe01__OppPayment__c pymt : [SELECT Id, acs_Society_Key_Cache__c, acs_Fund__c, npe01__Opportunity__r.acs_Modified__c, 
                                             acs_Revenue_Category__c, acs_Event_Year__c, npe01__Opportunity__c, acs_Modified__c   
                                             FROM npe01__OppPayment__c
                                             WHERE npe01__Opportunity__c in: OppIdMap.keySet()]) {
                                                 if(String.isBlank(pymt.acs_Society_Key_Cache__c) || String.isBlank(pymt.acs_Fund__c)
                                                    || String.isBlank(pymt.acs_Revenue_Category__c) || String.isBlank(pymt.acs_Event_Year__c)) {
                                                        OppIdMap.get(pymt.npe01__Opportunity__c).addError(Label.ACS_Opp_Pymt_SK_ClosedWon + '2');
                                                    }                                    
                                             }
        }
    }
    
    
    //17-May-2020 replaces onOppClosedWon method for 111479 
    public static void closedWonValidations(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        //PBI - 295357(HURON), By passing closed won opp validation(checkOpportunityFieldWhiteList)........
        System.debug('ACS_OpportunityTriggerHelper.bypassClosedOppVal======'+ACS_OpportunityTriggerHelper.bypassClosedOppVal);
        if(ACS_OpportunityTriggerHelper.bypassClosedOppVal) return;
        if(ACS_OpportunityTriggerHelper.isProcessChargeback) return;
        
        if (UserInfo.getUserType() == 'AutomatedProcess') return;
        
        
        if (FeatureManagement.checkPermission('Opportunity_Administration')) return;
        
        for(Opportunity opp : newList) {
            
            if (opp.acs_Modified__c || (!oldMap.isEmpty() && oldMap.get(opp.Id).acs_Modified__c)) {
                continue;
            }   
            
            if(oldMap != null && (oldMap.get(opp.Id).StageName == 'Closed Won' || oldMap.get(opp.Id).StageName == 'Closed Linked')
               && !System.isBatch() && !(opp.acs_Case_Refund_Type__c != oldMap.get(opp.Id).acs_Case_Refund_Type__c
                                         && opp.Amount != oldMap.get(opp.Id).Amount) && (opp.NSF_Payment__c == oldMap.get(opp.Id).NSF_Payment__c)) {
                                             
                                             checkOpportunityFieldWhiteList(opp, oldMap.get(opp.Id));
                                         }
        }
    }
    
    
    
    public static void updateEventSponsorshipAmountRaised(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldMap){
        
        Set<Id> updatedOppIds = new Set<Id>();
        Map<Id, acs_Event_Sponsorship__c> sponsorshipMap = new Map<Id, acs_Event_Sponsorship__c>();
        
        
        for (Opportunity opp : newMap.values()) {
            if (oldMap.containsKey(opp.Id)) {
                if ((opp.StageName == Constants_ACS.EXECUTION && oldMap.get(opp.Id).StageName != Constants_ACS.EXECUTION) ||
                    (opp.stageName == Constants_ACS.CLOSED_WON && oldMap.get(opp.Id).StageName != Constants_ACS.CLOSED_WON)) 
                {
                    updatedOppIds.add(opp.Id);
                }
            }
        }
        
        if (!updatedOppIds.isEmpty()) {
            for (acs_Event_Sponsorship__c ess : [SELECT Id, acs_Events__c, acs_Payment__c, acs_Opportunity_Stage__c
                                                 FROM acs_Event_Sponsorship__c
                                                 WHERE acs_Payment__r.npe01__Opportunity__c in :updatedOppIds])
            {
                sponsorshipMap.put(ess.Id, ess);
            }
            if (!sponsorshipMap.isEmpty()) {
                ACS_EventSponsorshipTriggerHelper.calculateWonSponsorships(sponsorshipMap, null);
            }
        }
    }
    
    public static void sendPaymentEmail(Map<Id,Opportunity> newMap, Map<Id,Opportunity> oldMap){
        
        Set<Id> oppSet = new Set<Id>();
        Set<Id> recSet = new Set<Id>();
        Set<Id> accountSet = new Set<Id>();
        Set<Id> userSet = new Set<Id>();
        
        
        for (RecordType lstRecType: [SELECT Id FROM RecordType WHERE Name = :Constants_ACS.OPPORTUNITY_RECORD_TYPE_NAME]){
            recSet.add(lstRecType.Id);
        }
        
        
        Map<Id,acs_Revenue_Category__c> inkindRevCategoryIdMap = new Map<Id,acs_Revenue_Category__c>([SELECT Id FROM acs_Revenue_Category__c WHERE (Name like '%in kind%' or Name like '%inkind%' or Name like '%in-kind%')]);
        Set<ID> inkindRevCategoryIds = inkindRevCategoryIdMap.keyset();
        
        
        for(Opportunity new_o : newMap.values()){    
            
            
            
            if(new_o.StageName != oldMap.get(new_o.Id).StageName || 
               (new_o.StageName == Constants_ACS.EXECUTION 
                && new_o.npe01__Number_of_Payments__c > oldMap.get(new_o.Id).npe01__Number_of_Payments__c))
            {
                if ((new_o.StageName == Constants_ACS.CLOSED_WON || new_o.StageName == Constants_ACS.EXECUTION)
                    && new_o.npe01__Amount_Outstanding__c >= 0 && recSet.contains(new_o.RecordTypeId)
                    && !excludeOpp(new_o, inkindRevCategoryIds) ) 
                {
                    if((new_o.StageName != oldMap.get(new_o.Id).StageName 
                        && new_o.npe01__Number_of_Payments__c >= 1)
                       || (new_o.acs_Payment_Schedule_Integration_Status__c != oldMap.get(new_o.Id).acs_Payment_Schedule_Integration_Status__c
                           && new_o.acs_Payment_Schedule_Integration_Status__c == 'Completed'
                           && new_o.npe01__Number_of_Payments__c >= 1)
                       || (new_o.npe01__Number_of_Payments__c > oldMap.get(new_o.Id).npe01__Number_of_Payments__c
                           && new_o.StageName == Constants_ACS.EXECUTION)) 
                    {
                        oppSet.add(new_o.Id);
                        accountSet.add(new_o.AccountId);
                        userSet.add(new_o.OwnerId);
                    }
                }
            }
        }
        
        
        Map<Id,npe01__OppPayment__c> paymentMap = new Map<Id,npe01__OppPayment__c>(); 
        Map<Id,User> userMap = new Map<Id,User>();
        if(!oppSet.isEmpty()){        
            for(npe01__OppPayment__c payment : [SELECT Id, npe01__Opportunity__c,npe01__Paid__c,npe01__Written_Off__c, acs_Society_Key__c
                                                ,acs_Revenue_Category__c,acs_Event_Year__c,acs_Fund__c, npe01__Payment_Date__c
                                                FROM   npe01__OppPayment__c
                                                WHERE  npe01__Opportunity__c IN : oppSet
                                                AND npe01__Written_Off__c = False])
            {
                paymentMap.put(payment.Id,payment);
            }
            
            for(User u: [SELECT Id, Email FROM  User WHERE  Id IN : userSet ])
            {
                userMap.put(u.Id,u);
            }
        }
        
        if(!paymentMap.isEmpty()) {
            for (Id oppId : oppSet) {
                
                Opportunity opp = newMap.get(oppId);
                String displayName = opp.Name;
                String emailAddress = '';
                
                try{
                    emailAddress = userMap.get(opp.OwnerId).Email;
                }
                catch (Exception ex){
                    ACS_ExceptionLogger.logException('ACS_OpportunityTriggerHelper', 'sendPaymentEmail', ex);
                }
                
                
                if (!String.isEmpty(emailAddress)){
                    String codingId = 'undefined';
                    Boolean allcodingIdSame = True;                    
                    List<npe01__OppPayment__c> paymentList = new List<npe01__OppPayment__c>();
                    
                    for (npe01__OppPayment__c payment : paymentMap.values()) {
                        if (payment.npe01__Opportunity__c == opp.Id) {
                            
                            if (codingId == 'undefined') {
                                codingId = getPaymentCoding(payment);
                            }
                            else{
                                if (codingId != getPaymentCoding(payment)){
                                    allcodingIdSame = false;
                                }
                            }
                            paymentList.add(payment);
                        }
                    }
                    
                    Set<String> barcodeSet = new Set<String>();
                    
                    
                    for (npe01__OppPayment__c payment : paymentList){
                        barcodeSet.add('P-' + payment.Id);
                    }
                    
                    
                    ACS_OpportunityTriggerHelper.generateAndSendPaySlip(barcodeSet, displayName, emailAddress);
                }
            }
        }
    }
    
    
    public static void getOpportunity(List<Opportunity> newList, Map<Id,Opportunity> oldMap, Map<Id,Opportunity> newMap){
        list<Id> OpportunityIdList = new list<Id>();
        list<Id> opptyId = new list<Id>();
        Map<Date, Id> PaymentDate = new Map<Date,Id>();
        Map<Date, Id> PaymentSchDate = new Map<Date,Id>();
        Set<Id> oppIds = new Set<Id>();
        
        for(Opportunity Opt: newList){
            if(Opt.StageName == Constants_ACS.CLOSED_WON
               && Opt.RecordTypeId == Constants_ACS.RECORDTYPE_OPPTY_MANAGED
               && !Opt.acs_Modified__c
               && Opt.npe01__Number_of_Payments__c > 1 
               && ((Opt.acs_Payment_Schedule_Integration_Status__c == Constants_ACS.RESUBMIT
                    && Opt.acs_Payment_Schedule_Integration_Status__c != oldMap.get(Opt.Id).acs_Payment_Schedule_Integration_Status__c)
                   || (Opt.acs_Payment_Schedule_Integration_Status__c == '' || Opt.acs_Payment_Schedule_Integration_Status__c == null || Opt.acs_Payment_Schedule_Integration_Status__c == 'None')))
                
                opptyId.add(Opt.Id);
        }
        
        if (!opptyId.isEmpty()) {
            
            for (Opportunity oppty :[SELECT Id, acs_Bookable__c, (SELECT Id, npe01__Payment_Date__c, npe01__Scheduled_Date__c
                                                                  FROM npe01__OppPayment__r)
                                     FROM Opportunity
                                     WHERE Id in :opptyId AND acs_Bookable__c = true]) {
                                         for (npe01__OppPayment__c payment : oppty.npe01__OppPayment__r) {
                                             if (payment.npe01__Payment_Date__c != null) {
                                                 PaymentDate.put(payment.npe01__Payment_Date__c, oppty.Id);
                                                 oppIds.add(oppty.Id);
                                             } else if (payment.npe01__Scheduled_Date__c != null) {
                                                 PaymentSchDate.put(payment.npe01__Scheduled_Date__c, oppty.Id);
                                                 oppIds.add(oppty.Id);
                                             } else {
                                                 newMap.get(oppty.Id).addError('No dates appear on this Opportunity Record.'); 
                                             }
                                         }
                                     }
            
            if(oppIds.size()>0) {
                OpportunityIdList.addAll(oppIds);
                BoomiCalloutHelper.sendOpportunityToBoomi(OpportunityIdList);
            }
        }
    }
    
  /**
* @Description This method takes the place of the PMT_Payment_TDTM after update trigger handler
*              from the NPSP executed on Opportunity. 
*/   
    public static void npspAfterUpdate(Map<Id, Opportunity> newMap, Map<Id, Opportunity> oldOppsMap, npsp.TDTM_Runnable.DMLWrapper dmlWrapper) {
        List<SObject> paymentsToInsert = new List<SObject> ();
        List<SObject> paymentsToUpdate = new List<SObject> ();
        
        List<Opportunity> updatedOpps = getOppsWithPayments(newMap.keySet());
        
        Map<Id, npe01__OppPayment__c> paymentsToUpdateMap = new Map<Id, npe01__OppPayment__c>();
        
        for (Opportunity thisOpp : updatedOpps) {
            Opportunity oldOpp = oldOppsMap.get(thisOpp.id);
            
            boolean mappingsUpdated = false;
            
            
            for (string s : paymentMappings.keyset()) {
                if (thisOpp.get(paymentMappings.get(s).npe01__Opportunity_Field__c) != oldOpp.get(paymentMappings.get(s).npe01__Opportunity_Field__c)) {
                    mappingsUpdated = true;
                }
            }
            
            
            
            Decimal totalPaymentsMade = getPaymentsMade(thisOpp);
            
            if (thisOpp.npe01__OppPayment__r.size() > 0) {
                
                if (((thisOpp.Amount != oldOpp.Amount) || (thisOpp.CloseDate != oldOpp.CloseDate) || mappingsUpdated == true) &&
                    (thisOpp.npe01__OppPayment__r[0].npe01__Scheduled_Date__c == oldOpp.CloseDate || thisOpp.npe01__OppPayment__r[0].npe01__Scheduled_Date__c == thisOpp.CloseDate) &&
                    (thisOpp.npe01__OppPayment__r[0].npe01__Payment_Amount__c == oldOpp.Amount || thisOpp.npe01__OppPayment__r[0].npe01__Payment_Amount__c == thisOpp.Amount) &&
                    thisOpp.npe01__OppPayment__r.size() == 1 &&
                    thisOpp.npe01__OppPayment__r[0].npe01__paid__c == False &&
                    
                    !thisOpp.isClosed && thisOpp.amount > 0 &&
                    totalPaymentsMade == 0) {
                        thisOpp.npe01__OppPayment__r[0].npe01__scheduled_date__c = thisOpp.closeDate;
                        thisOpp.npe01__OppPayment__r[0].npe01__payment_amount__c = thisOpp.amount;
                        
                        
                        if (paymentMappings.size() > 0) {
                            for (string s : paymentMappings.keyset()) {
                                npe01__Payment_Field_Mapping_Settings__c pfms = paymentMappings.get(s);
                                string x = pfms.npe01__Opportunity_Field__c;
                                if (thisOpp.get(x) != null)
                                    thisOpp.npe01__OppPayment__r[0].put(pfms.npe01__Payment_Field__c, thisOpp.get(x));
                            }
                        }
                        
                        
                        paymentsToUpdateMap.put(thisOpp.npe01__OppPayment__r[0].Id, thisOpp.npe01__OppPayment__r[0]);
                    }
                
                else if (thisOpp.isClosed && !thisOpp.isWon) {
                    
                    for (npe01__OppPayment__c thisPayment : thisOpp.npe01__OppPayment__r) {
                        if (thisPayment.npe01__Paid__c == False && thisPayment.npe01__Written_Off__c == False) {
                            thisPayment.npe01__Written_Off__c = true;
                            
                            paymentsToUpdateMap.put(thisPayment.Id, thisPayment);
                        }
                    }
                }
            }
            
            else if (
                thisOpp.Amount != null && thisOpp.Amount != 0 &&
                (thisOpp.IsClosed == false || thisOpp.IsWon == true) &&
                (oldOpp.Amount == null || oldOpp.Amount == 0) &&
                isNoPaymentForOpp(thisOpp) == false
            ) {
                paymentsToInsert.add(createOpportunityPayment(thisOpp, paymentCurrencyField, oppCurrencyField));
            }
        }
        
        
        handleSegmentUpdates(updatedOpps, oldOppsMap, paymentsToUpdateMap);
        
        
        if (!paymentsToUpdateMap.isEmpty())
        {
            dmlWrapper.objectsToUpdate.addAll((list<SObject>) paymentsToUpdateMap.values());
        }
        if (!paymentsToInsert.isEmpty())
        {
            dmlWrapper.objectsToInsert.addAll((list<SObject>) paymentsToInsert);
        }
        
    }
    
    public static void afterLinkingOrUnlikingOpportunity(List<Opportunity> newList,Map<Id,Opportunity> oldMap, Map<Id,Opportunity> newMap){
        
        Map<Id, Opportunity> unlinkedBookableMOs = new Map<Id, Opportunity>();
        Map<Id, Opportunity> linkedBookableMOs = new Map<Id, Opportunity>();
        Map<Id, Opportunity> unlinkedBookableACs = new Map<Id, Opportunity>(); 
        Map<Id, Opportunity> linkedBookableACs = new Map<Id, Opportunity>();
        Id recId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Auto - Created').getRecordTypeId();
        
        List<Opportunity> lstOpp = [SELECT Id, Name, acs_Linked_Opportunity__c,acs_Modified__c, RecordTypeId,
                                    (SELECT Id, acs_Primary_Linked_AC_Payment__c, acs_Source_Linked_Payment__c, npe01__Paid__c, acs_Modified__c, 
                                     acs_Modification_Type__c, acs_Type__c, acs_Linked_Payment__c, acs_Linkage_User__c,
                                     acs_Linkage_Date__c, npe01__Payment_Amount__c, npe01__Payment_Date__c
                                     FROM npe01__OppPayment__r) 
                                    FROM Opportunity WHERE Id IN : newMap.keySet()];
        
        set<String> setManageOppId = new set<String>();
        set<String> setUnlinkingOppId = new set<String>();
        set<String> setLinkingOppOd = new set<String>();
        set<String> setUnlinkingAcPayId = new set<String>();
        
        for(Opportunity objOpp : lstOpp) {
            if(objOpp.acs_Linked_Opportunity__c != oldMap.get(objOpp.Id).acs_Linked_Opportunity__c && objOpp.RecordTypeId == recId){
                if(objOpp.acs_Linked_Opportunity__c != null) {
                    setManageOppId.add(objOpp.acs_Linked_Opportunity__c);
                    setLinkingOppOd.add(objOpp.acs_Linked_Opportunity__c);
                } else if(oldMap.get(objOpp.Id).acs_Linked_Opportunity__c != null) {
                    
                    
                    for(npe01__OppPayment__c acPayment : objOpp.npe01__OppPayment__r){
                        if(acPayment.acs_Type__c != 'Reversal'){
                            setUnlinkingAcPayId.add(acPayment.Id);
                        }
                    }
                    
                    setManageOppId.add(oldMap.get(objOpp.Id).acs_Linked_Opportunity__c);
                    setUnlinkingOppId.add(oldMap.get(objOpp.Id).acs_Linked_Opportunity__c);
                }
            }
        } 
        
        
        System.debug('Managed Opp set '+ setManageOppId);
        if(!setManageOppId.isEmpty()) {
            
            List<Opportunity> lstManageOpp = [SELECT Id, Name, acs_Bookable__c, acs_Linked_Opportunity__c,acs_Modified__c, StageName, acs_Number_Of_Linked_Opportunities__c,
                                              (SELECT Id, Name, acs_Primary_Linked_AC_Payment__c, acs_Source_Linked_Payment__c, npe01__Paid__c, acs_Modified__c, acs_Modification_Type__c, acs_Linkage_User__c,
                                               acs_Linkage_Date__c, npe01__Payment_Amount__c, npe01__Payment_Date__c, acs_Linked_Payment__c FROM npe01__OppPayment__r) 
                                              FROM Opportunity WHERE Id IN : setManageOppId];
            
            for(Opportunity objOpp : lstManageOpp) {
                
                if(setLinkingOppOd.contains(objOpp.Id)){
                    if(objOpp.acs_Bookable__c){
                        linkedBookableMOs.put(objOpp.Id, objOpp);
                    }
                }
                
                if(setUnlinkingOppId.contains(objOpp.Id)){
                    if(objOpp.acs_Bookable__c){
                        unlinkedBookableMOs.put(objOpp.Id, objOpp);
                    }
                }
            }
        }
        
        
        
        for(Opportunity objOpp : lstOpp) { 
            if(objOpp.acs_Linked_Opportunity__c != oldMap.get(objOpp.Id).acs_Linked_Opportunity__c && objOpp.RecordTypeId == recId){
                
                if(objOpp.acs_Linked_Opportunity__c == null && unlinkedBookableMOs.containsKey(oldMap.get(objOpp.Id).acs_Linked_Opportunity__c)){  
                    unlinkedBookableACs.put(oldMap.get(objOpp.Id).acs_Linked_Opportunity__c, objOpp);
                }
                
                if(objOpp.acs_Linked_Opportunity__c != null && linkedBookableMOs.containsKey(objOpp.acs_Linked_Opportunity__c)){
                    linkedBookableACs.put(objOpp.acs_Linked_Opportunity__c,objOpp);
                }
            }
        }
        
        if(!unlinkedBookableMOs.isEmpty() && !unlinkedBookableACs.isEmpty()){
            sendBookableUnlinkingNotification(unlinkedBookableMOs, unlinkedBookableACs);
        }
        
        if(!linkedBookableMOs.isEmpty() && !linkedBookableACs.isEmpty()){
            sendBookablelinkingNotification(linkedBookableMOs, linkedBookableACs);
        }
    }
    
    public static void managedOpportunityNotification(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        
        Id oppId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Auto - Created').getRecordTypeId();
        Set<String> setOppId = new Set<String>();
        Set<Id> unlinkedMOIds = new Set<Id>(); 
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>(); 
        
        for(Opportunity objOpp: newList) {
            if(objOpp.acs_Linked_Opportunity__c != null && oldMap.get(objOpp.Id).acs_Linked_Opportunity__c != objOpp.acs_Linked_Opportunity__c && objOpp.RecordTypeid == oppId) {
                setOppId.add(objOpp.acs_Linked_Opportunity__c);
            }
            if(objOpp.acs_Linked_Opportunity__c == null && oldMap.get(objOpp.Id).acs_Linked_Opportunity__c != objOpp.acs_Linked_Opportunity__c && objOpp.RecordTypeid == oppId) {
                unlinkedMOIds.add(oldMap.get(objOpp.Id).acs_Linked_Opportunity__c );
            }
        } 
        
        for(Opportunity objOpp: [Select Id, Name, Owner.Email From Opportunity Where Id IN: setOppId AND RecordType.DeveloperName = 'Managed_Opportunity']) {
            Messaging.SingleEmailMessage linkMail = new Messaging.SingleEmailMessage();
            linkMail.setToAddresses(new String[] {objOpp.Owner.Email});
            linkMail.setSubject('Linked Managed Opportunity');
            String messageBody = '<html><body>A Managed Opportunity for which you are the record owner, has been linked. {'+objOpp.Name+', '+objOpp.Id+'}</body></html>';
            linkMail.setHtmlBody(messageBody); 
            emails.add(linkMail);
        }
        
        for(Opportunity unlinkedOpp : [SELECT Id, acs_Bookable__c, Name, Owner.Email FROM Opportunity 
                                       WHERE Id IN :unlinkedMOIds AND RecordType.DeveloperName = 'Managed_Opportunity']) {
                                           Messaging.SingleEmailMessage unlinkMail = new Messaging.SingleEmailMessage();
                                           unlinkMail.setToAddresses(new String[] {unlinkedOpp.Owner.Email});
                                           unlinkMail.setSubject('Unlinked Managed Opportunity');
                                           String messageBody = '<html><body>A Managed Opportunity for which you are the record owner, has been unlinked. {'+unlinkedOpp.Name+', '+unlinkedOpp.Id+'}</body></html>';
                                           unlinkMail.setHtmlBody(messageBody); 
                                           emails.add(unlinkMail);
                                       }
        if(!emails.isEmpty()){ 
            Messaging.sendEmail(emails);
        }
        
    }
    
    private static boolean canDisplaytypesCopy(Schema.Displaytype dtSrc, Schema.Displaytype dtTgt) {
        
        if (dtSrc == dtTgt)
            return true;
        
        
        if (dtSrc == Schema.Displaytype.Date && dtTgt == Schema.Displaytype.DateTime)
            return true;
        
        
        if ((dtSrc == Schema.Displaytype.Currency ||
             dtSrc == Schema.Displaytype.Double ||
             dtSrc == Schema.Displaytype.Integer ||
             dtSrc == Schema.Displaytype.Percent) &&
            (dtTgt == Schema.Displaytype.Currency ||
             dtTgt == Schema.Displaytype.Double ||
             dtTgt == Schema.Displaytype.Integer ||
             dtTgt == Schema.Displaytype.Percent)) {
                 return true;
             }
        
        
        if (dtSrc == Schema.Displaytype.String && dtTgt == Schema.Displaytype.TextArea)
            return true;
        
        return false;
    }
    
    private static npe01__Contacts_And_Orgs_Settings__c getContactsSettings() {
        npe01__Contacts_And_Orgs_Settings__c contactsSettings;
        if (Test.isRunningTest()) {
            contactsSettings = new npe01__Contacts_And_Orgs_Settings__c();
            configContactsSettings(contactsSettings);
        } else {
            contactsSettings = npe01__Contacts_And_Orgs_Settings__c.getInstance();
            if (contactsSettings.Id == null)
                contactsSettings = getOrgContactsSettings();
        }
        return contactsSettings;
    }
    
    public static npe01__Contacts_And_Orgs_Settings__c getOrgContactsSettings() {
        npe01__Contacts_And_Orgs_Settings__c orgContactsSettings = npe01__Contacts_And_Orgs_Settings__c.getOrgDefaults();
        if (orgContactsSettings.Id == null) {
            configContactsSettings(orgContactsSettings);
            orgContactsSettings.Setupownerid = UserInfo.getOrganizationId();
            if (!Test.isRunningTest()) {
                upsert orgContactsSettings;
            }
        }
        return orgContactsSettings;
    }
    
    private static void configContactsSettings(npe01__Contacts_And_Orgs_Settings__c cs) {
        
        cs.npe01__Enable_Opportunity_Contact_Role_Trigger__c = false;
        cs.npe01__Payments_Enabled__c = true;
        cs.npe01__Opportunity_Contact_Role_Default_role__c = 'Donor';
        cs.npsp__Contact_Role_for_Organizational_Opps__c = 'Soft Credit';
        cs.npe01__Account_Processor__c = 'Household Account';
        cs.npsp__Opp_RecTypes_Excluded_for_Payments__c = null;
        cs.npsp__Opp_Types_Excluded_for_Payments__c = null;
        Recordtypeinfo householdAccount = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Household Account');
        if (householdAccount != null)
            cs.npe01__HH_Account_RecordTypeID__c = householdAccount.getRecordTypeId();
    }
    
    // 17-May-2020 Replaces getOpportunityFields method for 111479
    public static void checkOpportunityFieldWhiteList(Opportunity newOpp, Opportunity oldOpp) {
        
        
        
        Schema.FieldSet fs = Schema.SObjectType.Opportunity.fieldSets.ClosedWon_WhiteListedFields;
        Set<String> whitelistedFields = new Set<String>();
        for (Schema.FieldSetMember fsm : fs.getFields()) {
            whitelistedFields.add(fsm.getFieldPath());
            System.debug('Adding whitelist field: ' + fsm.getFieldPath());
        }
        
        List<String> youCannotUpdateTheseFields = new List<String>();
        Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
        for (Schema.SObjectField oppField : oppFields.values()) {
            Schema.DescribeFieldResult ofd = oppField.getDescribe();
            
            
            if (ofd.isUpdateable() && newOpp.get(oppField) != oldOpp.get(oppField) && !whitelistedFields.contains(ofd.getName())) {
                
                if (ofd.getName() == 'AccountId' && FeatureManagement.checkPermission('Manage_Household')) {
                    continue;
                }
                youCannotUpdateTheseFields.add(ofd.getLabel());
                System.debug('You cannot update ' + ofd.getLabel() + ' name is ' + ofd.getName());
            }
        }
        
        ValidationRules__c vrs = ValidationRules__c.getInstance(); 
        Boolean mergevr = vrs.get('Contact_MergeRequest_Validation__c') == null || (Boolean)vrs.get('Contact_MergeRequest_Validation__c'); 
        
        
        if (!youCannotUpdateTheseFields.isEmpty() && mergevr) {
            String errorFields = ''; 
            do {
                if (errorFields == '') {
                    errorFields = youCannotUpdateTheseFields[0];
                } else {
                    errorFields += ', ' + youCannotUpdateTheseFields[0];
                }
                youCannotUpdateTheseFields.remove(0);
            } while (!youCannotUpdateTheseFields.isEmpty());
            
            newOpp.addError('These fields may not be changed once an Opportunity is Closed Won: ' + errorFields);
        }
    }
    
    
    
    public static boolean excludeOpp(Opportunity opp, Set<ID> inkindRevCategoryIds) {
        
        if (inkindRevCategoryIds.contains(opp.acs_Revenue_Category__c)) {
            return true;
        }
        
        if (opp.npe01__Number_of_Payments__c == opp.acs_Payments_With_Securites__c) {
            return true;
        }
        
        if (opp.Type == 'Employee Engagement' || opp.Type == 'Workplace Engagement' || opp.Type == 'Health Initiative') {
            return true;
        }
        
        return false;
    }
    
    public static String getPaymentCoding (npe01__OppPayment__c payment) {
        
        String codingId = '';
        codingId += String.isEmpty(payment.acs_Society_Key__c) ? 'emptysk' : payment.acs_Society_Key__c;
        codingId += String.isEmpty(payment.acs_Revenue_Category__c) ? 'emptyrc' : payment.acs_Revenue_Category__c;
        codingId += String.isEmpty(payment.acs_Event_Year__c) ? 'emptyey' : payment.acs_Event_Year__c;
        codingId += String.isEmpty(payment.acs_Fund__c) ? 'emptyfd' : payment.acs_Fund__c;
        codingId += payment.npe01__Payment_Date__c == null ? 'emptydt' : payment.npe01__Payment_Date__c.format();
        
        return codingId;
    }
    
    public static Boolean generateAndSendPaySlip (Set<String> barcodeSet, String displayName, String emailTo) {
        Boolean rtnValue = false;
        String barcodes = String.join((Iterable<String>)barcodeSet, ',');
        
        
        EmailTemplate paySlipTmp = [SELECT Id, Name, Body, Subject, Markup
                                    FROM EmailTemplate
                                    WHERE Name =: Constants_ACS.PAYMENT_PAYSLIP_EMAIL_TEXT];
        
        if(paySlipTmp != null) {
            
            List<Messaging.SingleEmailMessage> allMails = new List<Messaging.SingleEmailMessage>();
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(emailTo.split(','));
            
            
            String mailBody = paySlipTmp.Body;
            
            acs_Payslip_Custom_URL__c payslipCustomSetting = acs_Payslip_Custom_URL__c.getInstance();
            String customURL = payslipCustomSetting.acs_Custom_URL__c;
            String payslipURL = customURL +'?barcode=' + barcodes;
            
            mailBody = mailBody.replace('{!PayslipURL}', payslipURL);
            mail.setSubject(paySlipTmp.Subject);
            mail.setHtmlBody(mailBody);
            allMails.add(mail);
            
            try{
                if(!allMails.isEmpty()){
                    Messaging.sendEmail(allMails, true);
                    rtnValue = true;
                }
            }
            catch(Exception ex){
                if (ex.getMessage().contains('Single email is not enabled')){
                    
                    system.debug(ex.getMessage());
                }
                else{
                    apexLogHandler.apexLog emailLog = new apexLogHandler.apexLog('ACS_OpportunityTriggerHelper','email_send', 'Payslip Email failed to send');
                    emailLog.logException(ex);
                    emailLog.saveLogs();
                }
            }
        } 
        return rtnValue;
    } 
    
    private static List<Opportunity> getOppsWithPayments(Set<Id> oppList){
        return [SELECT Id,CloseDate, Amount, isClosed, isWon, npe01__Do_Not_Automatically_Create_Payment__c, Type, RecordTypeId, 
                acs_Society_Key_Cache__c, acs_Event_Year__c, acs_Revenue_Category__c, acs_Fund__c, acs_Society_Key__c, 
                (SELECT id, npe01__Paid__c, npe01__Opportunity__c, npe01__Payment_Amount__c, npe01__Payment_Date__c, npe01__Scheduled_Date__c, npe01__Written_Off__c FROM Opportunity.npe01__OppPayment__r)
                FROM Opportunity WHERE Id IN :oppList];
    }
    
    private static Decimal getPaymentsMade(Opportunity currentOpp) {
        Decimal totalPayments = 0;
        for (npe01__OppPayment__c pmt : currentOpp.npe01__OppPayment__r) {
            if (pmt.npe01__Paid__c == true) {
                totalPayments += pmt.npe01__Payment_Amount__c;
            }
        }
        return totalPayments;
    }
    @testvisible
    private static boolean isNoPaymentForOpp(Opportunity opp) {
        if (opp.npe01__Do_Not_Automatically_Create_Payment__c)
            return true;
        if (setOppTypeNoPayment.contains(opp.Type))
            return true;
        if (setOppRecordTypeIdNoPayment.contains((id) opp.get('RecordTypeId')))
            return true;
        return false;
    }
    @testvisible
    private static npe01__OppPayment__c createOpportunityPayment(Opportunity newOpportunity, SObjectField paymentCurrencyField, SObjectField oppCurrencyField) {
        npe01__OppPayment__c opportunityPayment = new npe01__OppPayment__c(
            npe01__Opportunity__c = newOpportunity.Id,
            npe01__Paid__c = newOpportunity.IsClosed,
            npe01__Payment_Amount__c = newOpportunity.Amount
        );
        
        if (opportunityPayment.npe01__Paid__c) {
            opportunityPayment.npe01__Payment_Date__c = newOpportunity.CloseDate;
        } else {
            opportunityPayment.npe01__Scheduled_Date__c = newOpportunity.CloseDate;
        }
        
        
        if (paymentCurrencyField != null && oppCurrencyField != null) {
            opportunityPayment.put(paymentCurrencyField, newOpportunity.get(oppCurrencyField));
        }
        
        for (npe01__Payment_Field_Mapping_Settings__c paymentMapping : paymentMappings.values()) {
            if (newOpportunity.get(paymentMapping.npe01__Opportunity_Field__c) != null) {
                opportunityPayment.put(
                    paymentMapping.npe01__Payment_Field__c,
                    newOpportunity.get(paymentMapping.npe01__Opportunity_Field__c)
                );
            }
        }
        return opportunityPayment;
    }
    
    
    public static void sendBookableUnlinkingNotification(Map<Id, Opportunity> managedOpps, Map<Id, Opportunity> autoOpps){
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for(Opportunity opp : managedOpps.values()){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {Label.acs_Finance_Team_Email});
            mail.setSubject('Unlinked Bookable Managed Opportunity');
            String messageBody = '<html><body>A bookable Managed Opportunity has been unlinked: {' +
                opp.Name + ', ' + opp.Id + '} <br/> Previously Linked Auto-Created Opportunity: {' +  
                autoOpps.get(opp.Id).Name + ', ' + autoOpps.get(opp.Id).Id + '} <br/> ' + 
                'Managed Opportunity Payments: <br/> ';
            for(npe01__OppPayment__c moPayment : opp.npe01__OppPayment__r){
                messageBody += 'Id: {' + moPayment.Id + '}, Payment Amount: {' + moPayment.npe01__Payment_Amount__c + '}, Payment Date: {' + moPayment.npe01__Payment_Date__c + '} <br/>'; 
            }
            messageBody += 'Auto-Created Payments: <br/>';
            for(npe01__OppPayment__c acPayment : autoOpps.get(opp.Id).npe01__OppPayment__r){
                messageBody += 'Id: {' + acPayment.Id + '}, Payment Amount: {' + acPayment.npe01__Payment_Amount__c + '}, Payment Date: {' + acPayment.npe01__Payment_Date__c + 
                    'Linkage User: {' + acPayment.acs_Linkage_User__c + '}, Linkage Date: {' + acPayment.acs_Linkage_Date__c + '} <br/>'; 
            }
            messageBody += ' </body></html>';
            mail.setHtmlBody(messageBody); 
            emails.add(mail);
        }
        
        if(!emails.isEmpty()&&!test.isrunningtest()){
            Messaging.sendEmail(emails);
        }
    }
    
    public static void sendBookablelinkingNotification(Map<Id, Opportunity> managedOpps, Map<Id, Opportunity> autoOpps){
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for(Opportunity opp : managedOpps.values()){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {Label.acs_Finance_Team_Email});
            mail.setSubject('Linked Bookable Managed Opportunity');
            String messageBody = '<html><body>A bookable Managed Opportunity has been linked: {' +
                opp.Name + ', ' + opp.Id + '} <br/> Linked Auto-Created Opportunity: {' +  
                autoOpps.get(opp.Id).Name + ', ' + autoOpps.get(opp.Id).Id + '} <br/> ' + 
                'Managed Opportunity Payments: <br/> ';
            for(npe01__OppPayment__c moPayment : opp.npe01__OppPayment__r){
                messageBody += 'Id: {' + moPayment.Id + '}, Payment Amount: {' + moPayment.npe01__Payment_Amount__c + '}, Payment Date: {' + moPayment.npe01__Payment_Date__c + '} <br/>'; 
            }
            messageBody += 'Auto-Created Payments: <br/>';
            for(npe01__OppPayment__c acPayment : autoOpps.get(opp.Id).npe01__OppPayment__r){
                messageBody += 'Id: {' + acPayment.Id + '}, Payment Amount: {' + acPayment.npe01__Payment_Amount__c + '}, Payment Date: {' + acPayment.npe01__Payment_Date__c + 
                    'Linkage User: {' + acPayment.acs_Linkage_User__c + '}, Linkage Date: {' + acPayment.acs_Linkage_Date__c + '} <br/>'; 
            }
            messageBody += 'manual action is required in order to reconcile these changes in financial systems. <br/>';
            messageBody += ' </body></html>';
            mail.setHtmlBody(messageBody); 
            emails.add(mail);
        }
        
        if(!emails.isEmpty()&&!test.isrunningtest()){
            Messaging.sendEmail(emails);
        }
    }
    
    
    /**
* @Description Checks for updated segments on managed opportunity and updates payment where appropriate
*              Addresses BUG 165101/BUG 127750
* @param    newList List of Opportunities being updated
* @param    oldMap  Map of Opportunity values prior to update
* @param    paymentsToUpdateMap Map of payments being updated
*/    
    public static void handleSegmentUpdates(List<Opportunity> newList, Map<Id, Opportunity> oldMap, Map<Id, npe01__OppPayment__c> paymentsToUpdateMap) {
        Set<Id> oppIds = new Set<Id>();
        List<npe01__OppPayment__c> paymentList = new List<npe01__OppPayment__c>();
        Map<Id, Opportunity> SKUpdatedMap = new Map<Id, Opportunity>();
        Map<Id, Opportunity> EventYearUpdatedMap = new Map<Id, Opportunity>();
        Map<Id, Opportunity> RestrictionUpdatedMap = new Map<Id, Opportunity>();
        Map<Id, Opportunity> RevenueCategoryUpdatedMap = new Map<Id, Opportunity>();
        
        for (Opportunity opp : newList) {
            if (opp.npe01__OppPayment__r.size() > 0 && opp.RecordTypeId == Constants_ACS.RECORDTYPE_OPPTY_MANAGED && !opp.IsClosed) {
                if (oldMap.containsKey(opp.Id)) {
                    Opportunity oldOpp = oldMap.get(opp.Id);
                    Boolean paymentNeedsUpdate = false;
                    if (opp.acs_Society_Key_Cache__c != oldOpp.acs_Society_Key_Cache__c) {
                        SKUpdatedMap.put(opp.Id, opp);
                        paymentNeedsUpdate = true;
                    } 
                    if (opp.acs_Event_Year__c != oldOpp.acs_Event_Year__c) {
                        EventYearUpdatedMap.put(opp.Id, opp);
                        paymentNeedsUpdate = true;
                    } 
                    if (opp.acs_Revenue_Category__c != oldOpp.acs_Revenue_Category__c) {
                        RevenueCategoryUpdatedMap.put(opp.Id, opp);
                        paymentNeedsUpdate = true;
                    } 
                    if (opp.acs_Fund__c != oldOpp.acs_Fund__c) {
                        RestrictionUpdatedMap.put(opp.Id, opp);
                        paymentNeedsUpdate = true;
                    }
                    if (paymentNeedsUpdate) {
                        paymentList.addAll(opp.npe01__OppPayment__r);
                    }
                }
            }
        }
        
        if (!paymentList.isEmpty()) {
            for (npe01__OppPayment__c pymt : paymentList) {
                if (pymt.npe01__Paid__c) continue; 
                
                if (paymentsToUpdateMap.containsKey(pymt.Id)) {
                    pymt = paymentsToUpdateMap.get(pymt.Id);
                } else {
                    paymentsToUpdateMap.put(pymt.Id, pymt);
                }
                if (SKUpdatedMap.containsKey(pymt.npe01__Opportunity__c)) {
                    pymt.acs_Society_Key__c = SKUpdatedMap.get(pymt.npe01__Opportunity__c).acs_Society_Key__c;
                    pymt.acs_Society_Key_Cache__c = SKUpdatedMap.get(pymt.npe01__Opportunity__c).acs_Society_Key_Cache__c;
                }
                if (EventYearUpdatedMap.containsKey(pymt.npe01__Opportunity__c)) {
                    pymt.acs_Event_Year__c = EventYearUpdatedMap.get(pymt.npe01__Opportunity__c).acs_Event_Year__c;
                }
                if (RestrictionUpdatedMap.containsKey(pymt.npe01__Opportunity__c)) {
                    pymt.acs_Fund__c = RestrictionUpdatedMap.get(pymt.npe01__Opportunity__c).acs_Fund__c;
                }
                if (RevenueCategoryUpdatedMap.containsKey(pymt.npe01__Opportunity__c)) {
                    pymt.acs_Revenue_Category__c = RevenueCategoryUpdatedMap.get(pymt.npe01__Opportunity__c).acs_Revenue_Category__c;
                }
            }
        }
    }
    
    //PBI 169200 Huron :the Closed Date on the Managed Opportunity should update to the date that stage is selected to Closed Status.
    public static void updateClosedDate(List<Opportunity> newList, Map<Id, Opportunity> oldMap){
        for(Opportunity opp : newList) {
            Id Managed_Opp_recordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get(Constants_ACS.OPPORTUNITY_RECORD_TYPE_NAME).getRecordTypeId();
            
            if((opp.RecordTypeid==Managed_Opp_recordTypeId)&&
               ((opp.StageName == Constants_ACS.CLOSED_WON) || ( opp.StageName == Constants_ACS.CLOSED_LOST ))&&
               (oldMap.isEmpty() || oldMap.get(opp.Id).stageName !=opp.StageName)){
                   opp.CloseDate= System.Today();
               }
        }
    } 
    //PBI 185091 restrict opportunity to deletion     
    public static void validationDeleteOpportunity(List<Opportunity> oldList){        
        if(checkIfDeleteIsRestricted()){
            for(Opportunity opp: oldList){                
                opp.Name.addError(Label.OpportunityDeleteErrorMessage);                
            }
        }
    }
    //PBI 209321 Returns True if Opp Delete is restricted    
    public static Boolean checkIfDeleteIsRestricted(){ 
        Boolean isDeleteRestricted = false;
        Set<String> profileNames = new Set<String>{'SSBC User', 'ACS Standard User', 'NCIC User'}; 
        Profile prof = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];        
        if(profileNames.contains(prof.Name)){
            Set<String> psetNames = new Set<String>{Constants_ACS.PERMISSION_SET_FM, Constants_ACS.PERMSET_DataPowerUser, Constants_ACS.PERMSET_OpportunityAdmin};
            List<PermissionSetAssignment> userPermissions = [SELECT Id, PermissionSet.Name FROM PermissionSetAssignment 
                                                             WHERE AssigneeId = :UserInfo.getUserId() AND
                                                             PermissionSet.Name IN :psetNames];
            
            if(userPermissions.size() == 1 && userPermissions[0].PermissionSet.Name == Constants_ACS.PERMISSION_SET_FM)
                isDeleteRestricted = true;
        }
        return isDeleteRestricted;
    }

    // Populates the Account Plan lookup on new or updated Opportunities.
    public static void setAccountPlan(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> accountIds = new Set<Id>();
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Opportunity opportunity : newList) {
            if (String.isBlank(opportunity.AccountPlan__c)) {
                if (oldMap == null || opportunity.CloseDate != oldMap.get(opportunity.Id).CloseDate || opportunity.AccountId != oldMap.get(opportunity.Id).AccountId) {
                    opportunitiesToUpdate.add(opportunity);
                    accountIds.add(opportunity.AccountId);
                }
            }
        }

        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, (SELECT Id, CalendarYear__c FROM ACS_Plans__r) FROM Account WHERE Id IN :accountIds]);

        for (Opportunity opportunity : opportunitiesToUpdate) {
            Account account = accounts.get(opportunity.AccountId);
            if (account == null) {
                continue;
            }
            for (AccountPlan__c accountPlan : account.ACS_Plans__r) {
                if (String.valueOf(opportunity.CloseDate.year()) == accountPlan.CalendarYear__c) {
                    opportunity.AccountPlan__c = accountPlan.Id;
                }
            }
        }
    }

    public static void incomingGrantsRollup(List<Opportunity> optyList, String optnType){

        Id moRecTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Managed Opportunity').getRecordTypeId();
        Set<Id> projectIds = new Set<Id>();
        Set<Id> fundIds    = new Set<Id>();
System.debug('Oppty Totals Log - Step 1');

        for(Opportunity optyRec : optyList){
            if(optyRec.acs_Parent_Project__c != null){
                projectIds.add(optyRec.acs_Parent_Project__c);
            }
            if(optyRec.acs_Fund__c  != null){
                fundIds.add(optyRec.acs_Fund__c);
            }
        }

        List<Opportunity> opptyCalcList = [Select Id, acs_Parent_Project__c, acs_Bookable__c,
                                                  Amount, npe01__Payments_Made__c, acs_Fund__c
                                             FROM Opportunity
                                            WHERE acs_Parent_Project__c IN :projectIds];

        List<ampi__Project__c> prjtRecsList = [Select Id, acs_Total_Invoiced_for_Project__c,
                                                      acs_Total_Paid_for_Project__c
                                                 FROM ampi__Project__c
                                                WHERE Id IN :projectIds];

        List<acs_Fund__c> fundRecsList = [Select Id, acs_Total_Invoiced__c,
                                                 Total_Paid__c
                                            FROM acs_Fund__c
                                           WHERE Id IN :fundIds];

        for(ampi__Project__c prjRec : prjtRecsList){
            Decimal totalAmount  = 0;
            Decimal totalPayment = 0;

            for(Opportunity optyRec : opptyCalcList){
                if(prjRec.Id == optyRec.acs_Parent_Project__c){
System.debug('Oppty Totals Log - ----------------------------------');
System.debug('Oppty Totals Log - acs_Parent_Project__c  '+optyRec.acs_Parent_Project__c);
System.debug('Oppty Totals Log - acs_Bookable__c        '+optyRec.acs_Bookable__c);
System.debug('Oppty Totals Log - ----------------------------------');

                    if(optyRec.acs_Bookable__c == True){
                        totalAmount += optyRec.Amount != null ? optyRec.Amount : 0;
System.debug('Oppty Totals Log - Incremental totalAmount  '+totalAmount);
                    }

                    totalPayment += optyRec.npe01__Payments_Made__c != null ? optyRec.npe01__Payments_Made__c : 0;
                }
            }

System.debug('Oppty Totals Log - ----------------------------------');
System.debug('Oppty Totals Log - Project totalAmount  '+totalAmount);
System.debug('Oppty Totals Log - Project totalPayment '+totalPayment);
System.debug('Oppty Totals Log - ----------------------------------');

            prjRec.acs_Total_Invoiced_for_Project__c = totalAmount;
            prjRec.acs_Total_Paid_for_Project__c     = totalPayment;
        }

        for(acs_Fund__c fundRec : fundRecsList){
            Decimal totalAmount  = 0;
            Decimal totalPayment = 0;

            for(Opportunity optyRec : opptyCalcList){
                if(fundRec.Id == optyRec.acs_Fund__c){
                    if(optyRec.acs_Bookable__c){
                        totalAmount += optyRec.Amount != null ? optyRec.Amount : 0;
                    }

                    totalPayment += optyRec.npe01__Payments_Made__c != null ? optyRec.npe01__Payments_Made__c : 0;
                }
            }

System.debug('Oppty Totals Log - ----------------------------------');
System.debug('Oppty Totals Log - Fund totalAmount  '+totalAmount);
System.debug('Oppty Totals Log - Fund totalPayment '+totalPayment);
System.debug('Oppty Totals Log - ----------------------------------');

            fundRec.acs_Total_Invoiced__c = totalAmount;
            fundRec.Total_Paid__c         = totalPayment;
        }

        try{
            update prjtRecsList;
System.debug('Oppty Totals Log - Project Records Updated Successfully!!!');
        }
        catch(Exception exp){
            AmpiFinancialTriggerHandler.createApexErrorLog('OpportunityTriggerHelper', 'Rollup to Project', 'Failed to Update Project records: '+exp.getMessage(), LoggingLevel.DEBUG, exp);
System.debug('Oppty Totals Log - Project Records Update Failed with '+exp.getMessage());
        }

        try{
            update fundRecsList;
System.debug('Oppty Totals Log - Funds Records Updated Successfully!!!');
        }
        catch(Exception exp){
            AmpiFinancialTriggerHandler.createApexErrorLog('OpportunityTriggerHelper', 'Rollup to Retriction', 'Failed to Update Fund/REstriction records: '+exp.getMessage(), LoggingLevel.DEBUG, exp);
System.debug('Oppty Totals Log - Funds Records Update Failed with '+exp.getMessage());
        }
    }

    /**
     * @description Checks if the Opportunity Close Date or Amount Changed. If so, it recalculates an related Account and Contact's soft credit fields.
     * @param newList List of updated Opportunities.
     * @param oldMap Map of old Opportunity values by Id.
     */
    public static void checkCloseDateAndAmount(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();

        for (Opportunity opportunity : newList) {
            if (opportunity.CloseDate != oldMap.get(opportunity.Id).CloseDate || opportunity.Amount != oldMap.get(opportunity.Id).Amount || opportunity.Number_of_Payments_Paid__c != oldMap.get(opportunity.Id).Number_of_Payments_Paid__c) {
                opportunityIds.add(opportunity.Id);
            }
        }

        if (!opportunityIds.isEmpty()) {
            List<npsp__Account_Soft_Credit__c> accountSoftCredits = [SELECT npsp__Account__c, npsp__Opportunity__c FROM npsp__Account_Soft_Credit__c WHERE npsp__Opportunity__c IN :opportunityIds];
            for (npsp__Account_Soft_Credit__c accountSoftCredit : accountSoftCredits) {
                accountIds.add(accountSoftCredit.npsp__Account__c);
            }

            List<Contact_Soft_Credit__c> contactSoftCredits = [SELECT Contact__c, Opportunity__c FROM Contact_Soft_Credit__c WHERE Opportunity__c IN :opportunityIds];
            for (Contact_Soft_Credit__c contactSoftCredit : contactSoftCredits) {
                contactIds.add(contactSoftCredit.Contact__c);
            }

            if (!accountIds.isEmpty()) {
                AccountSoftCreditRollupService.calculateSoftCreditRollups(accountIds);
            }

            if (!contactIds.isEmpty()) {
                ContactSoftCreditRollupService.calculateSoftCreditRollups(contactIds);
            }
        }
    }
    //PBI - 295357 (HURON), Setting bypassClosedOppVal true, which means it is coming from Update_Closed_Opportunity screen flow.....
    @InvocableMethod(label='set static value' description='sets the static value to true')
    public static void updateBypassVar() {
        ACS_OpportunityTriggerHelper.bypassClosedOppVal = true;
    }
}