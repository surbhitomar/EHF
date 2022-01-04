/*
###########################################################################
# File...................: Ehf_BatchLeadNContactJobExampleTest
# Version................: V1.0
# Created by.............: Coforge 
# Last Modified by.......: Coforge
# Created Date...........: 01-12-2021
# Last Modified Date.....: 01-12-2021 
# Description............: This class execute the dml operation to a sObject List, create error logs in 'Ehf_ApexErrorLog' object,
create a json document for the failed records while handling exception in any transaction and 
post on chatter for DML failed records with tagging to all admin users.
# Class.............: Ehf_ErrorHandler, Ehf_BatchLeadNContactJobExample
# Change Log.............: V1.0 Initial Version.

#############################################################################
*/ 
@isTest
public class Ehf_BatchLeadNContactJobExampleTest {

    @isTest
    public static void testSyncReportWithTestData() {
        list<lead> leadList= new list<lead>();
        
        Lead depErrorLead = new Lead(FirstName='Salesforce',LastName='Limit Department',Company='salesforcecodes',
                          leadsource='Web', Status = 'Working - Contacted');
        leadList.add(depErrorLead);
        Lead emailErrorLead = new Lead(FirstName='Salesforce',LastName='Wrong Email Check',Company='salesforcecodes',
                          leadsource='Web', Status = 'Working - Contacted');
        leadList.add(emailErrorLead);
        Lead lead1 = new Lead(FirstName='Salesforce',LastName='Test',Company='salesforcecodes',
                          leadsource='Web', Status = 'Working - Contacted');
        leadList.add(lead1);                  
        Lead lead2 = new Lead(FirstName='Salesforce',LastName='Correct',Company='salesforcecodes',
                          leadsource='Web', Status = 'Working - Contacted'); 
        leadList.add(lead2);
        Lead lead3 = new Lead(FirstName='Salesforce',LastName='AnnualRevenue',Company='salesforcecodes',
                          leadsource='Web', Status = 'Working - Contacted'); 
        leadList.add(lead3);
        
        insert leadList;
        Test.startTest();
        Ehf_BatchLeadNContactJobExample ba= new Ehf_BatchLeadNContactJobExample();
        Id jobid= Database.executeBatch(ba,200);
        Test.stopTest();
        list<contact> contactList= [select id from contact where createddate = today];
        system.debug('--contactList-->'+contactList);
        //system.assertEquals(2, contactList.size());
    }
    
    
}