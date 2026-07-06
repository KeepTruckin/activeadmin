/**
 * @description Test class for ESYS-27314 / ESYS-28342: Capchase - Update VF Check records flow.
 */
@isTest
private class CapchaseBuyerFlowTest {

    private static Map<String, SObject> createTestAccountAndOpp() {
        K2Web__c k2web = K2Web__c.getOrgDefaults();
        if (k2web.API_Key__c == null) {
            k2web.API_Key__c = 'TestKey';
            upsert k2web K2Web__c.Id;
        }

        Id oppDefaultRtId = [SELECT Id FROM RecordType
                             WHERE SobjectType = 'Opportunity' AND DeveloperName = 'Default' LIMIT 1].Id;
        Id vfPreCheckRtId = [SELECT Id FROM RecordType
                             WHERE SobjectType = 'VF_Check__c' AND DeveloperName = 'Pre_Check' LIMIT 1].Id;

        Account acc = new Account(
            Name          = 'Capchase Flow Test ' + Crypto.getRandomLong(),
            Company_Id__c = 'C' + String.valueOf(Crypto.getRandomLong()).right(8)
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name         = 'Capchase Test Opp',
            AccountId    = acc.Id,
            StageName    = 'Prospecting',
            CloseDate    = Date.today().addDays(30),
            RecordTypeId = oppDefaultRtId
        );
        insert opp;

        return new Map<String, SObject>{
            'account'        => acc,
            'opportunity'    => opp,
            'oppDefaultRtId' => new RecordType(Id = oppDefaultRtId),
            'vfPreCheckRtId' => new RecordType(Id = vfPreCheckRtId)
        };
    }

    private static capchaseapp__CapchaseBuyer__c createBuyer(Id accId) {
        capchaseapp__CapchaseBuyer__c buyer = new capchaseapp__CapchaseBuyer__c(
            Name                               = accId,
            capchaseapp__Minimum_Amount__c     = 1000,
            capchaseapp__Maximum_Amount__c     = 250000,
            capchaseapp__Maximum_Duration__c   = 60,
            capchaseapp__Offer_Expiration_Date__c = Date.today().addDays(90)
        );
        insert buyer;
        return buyer;
    }

    private static VF_Check__c buildVF(Id oppId, Id accId, Id buyerId, Id rtId,
                                        String lender, String status,
                                        Decimal tcv, Decimal months) {
        return new VF_Check__c(
            Opportunity__c             = oppId,
            Account__c                 = accId,
            CapchaseBuyer__c           = buyerId,
            Lender__c                  = lender,
            Status__c                  = status,
            Total_Contract_Value__c    = tcv,
            Contract_Length__c         = months,
            RecordTypeId               = rtId,
            Authorized_Signer_Email__c = 'test@example.com',
            Authorized_Signer_Name__c  = 'Test Signer',
            Business_Legal_Name__c     = 'Test Business LLC'
        );
    }

    private static void triggerFlow(capchaseapp__CapchaseBuyer__c buyer, String kyb) {
        buyer.capchaseapp__KYB_Result__c = kyb;
        update buyer;
    }

    private static String getOppOwnerRole(Id oppId) {
        return [SELECT Owner.UserRole.Name FROM Opportunity WHERE Id = :oppId].Owner.UserRole.Name;
    }

    private static void assertCloneFields(VF_Check__c clone, Id oppId) {
        System.assertEquals('New', clone.Status__c, 'Clone Status should be New');
        System.assert(String.isBlank(clone.Lender__c), 'Clone Lender should be blank');
        System.assertEquals(null, clone.Approval_Expiration_Date__c, 'Clone ApprovalExpiry should be blank');
        String expectedRole = getOppOwnerRole(oppId);
        if (String.isNotBlank(expectedRole)) {
            System.assertEquals(expectedRole, clone.Created_By_Role__c,
                'Clone Created_By_Role should match Opportunity Owner UserRole');
        }
    }

    @isTest
    static void testApproved() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Pending Submission', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'APPROVED');
        Test.stopTest();

        VF_Check__c result = [SELECT Status__c, Lender_Financing_Amount__c, Approval_Expiration_Date__c
                               FROM VF_Check__c WHERE Id = :vf.Id];
        System.assertEquals('Approved', result.Status__c);
        System.assertEquals(250000, result.Lender_Financing_Amount__c);
        System.assertNotEquals(null, result.Approval_Expiration_Date__c);

        Integer clones = [SELECT COUNT() FROM VF_Check__c WHERE Opportunity__c = :opp.Id AND Id != :vf.Id];
        System.assertEquals(0, clones);
    }

    @isTest
    static void testRejected() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Pending Submission', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'REJECTED');
        Test.stopTest();

        System.assertEquals('Declined', [SELECT Status__c FROM VF_Check__c WHERE Id = :vf.Id].Status__c);

        List<VF_Check__c> clones = [SELECT Status__c, Lender__c, Approval_Expiration_Date__c, Created_By_Role__c
                                     FROM VF_Check__c
                                     WHERE Opportunity__c = :opp.Id AND Id != :vf.Id
                                     ORDER BY CreatedDate DESC];
        System.assertEquals(1, clones.size());
        assertCloneFields(clones[0], opp.Id);
    }

    @isTest
    static void testPending() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Pending Submission', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'PENDING');
        Test.stopTest();

        System.assertEquals('Pending Lender Decision',
            [SELECT Status__c FROM VF_Check__c WHERE Id = :vf.Id].Status__c);
        System.assertEquals(0, [SELECT COUNT() FROM VF_Check__c WHERE Opportunity__c = :opp.Id AND Id != :vf.Id]);
    }

    @isTest
    static void testManualReview() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'New', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'MANUAL_REVIEW');
        Test.stopTest();

        System.assertEquals('Pending Lender Decision',
            [SELECT Status__c FROM VF_Check__c WHERE Id = :vf.Id].Status__c);
        System.assertEquals(0, [SELECT COUNT() FROM VF_Check__c WHERE Opportunity__c = :opp.Id AND Id != :vf.Id]);
    }

    @isTest
    static void testMissingInfo() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Pending Lender Decision', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'MISSING_INFO');
        Test.stopTest();

        System.assertEquals('Information Required',
            [SELECT Status__c FROM VF_Check__c WHERE Id = :vf.Id].Status__c);

        List<VF_Check__c> clones = [SELECT Status__c, Lender__c, Approval_Expiration_Date__c, Created_By_Role__c
                                     FROM VF_Check__c WHERE Opportunity__c = :opp.Id AND Id != :vf.Id];
        System.assertEquals(1, clones.size(), 'MISSING_INFO should clone without owner gate');
        assertCloneFields(clones[0], opp.Id);
    }

    @isTest
    static void testDataRequired() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Pending Submission', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'DATA_REQUIRED');
        Test.stopTest();

        System.assertEquals('Information Required',
            [SELECT Status__c FROM VF_Check__c WHERE Id = :vf.Id].Status__c);

        List<VF_Check__c> clones = [SELECT Status__c, Lender__c, Approval_Expiration_Date__c, Created_By_Role__c
                                     FROM VF_Check__c WHERE Opportunity__c = :opp.Id AND Id != :vf.Id];
        System.assertEquals(1, clones.size(), 'DATA_REQUIRED should clone without owner gate');
        assertCloneFields(clones[0], opp.Id);
    }

    @isTest
    static void testAlreadyDeclined() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Declined', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'APPROVED');
        Test.stopTest();

        System.assertEquals('Declined', [SELECT Status__c FROM VF_Check__c WHERE Id = :vf.Id].Status__c);
    }

    @isTest
    static void testNonCapchaseLender() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vf = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Vartana', 'Pending Submission', 50000, 24);
        insert vf;

        Test.startTest();
        triggerFlow(buyer, 'APPROVED');
        Test.stopTest();

        System.assertEquals('Pending Submission',
            [SELECT Status__c FROM VF_Check__c WHERE Id = :vf.Id].Status__c);
    }

    @isTest
    static void testMultipleVFChecks() {
        Map<String, SObject> data = createTestAccountAndOpp();
        Account acc = (Account) data.get('account');
        Opportunity opp = (Opportunity) data.get('opportunity');
        Id vfRtId = data.get('vfPreCheckRtId').Id;

        capchaseapp__CapchaseBuyer__c buyer = createBuyer(acc.Id);
        VF_Check__c vfA = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Pending Submission', 50000, 24);
        VF_Check__c vfB = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'New', 50000, 24);
        VF_Check__c vfC = buildVF(opp.Id, acc.Id, buyer.Id, vfRtId, 'Capchase', 'Approved', 50000, 24);
        insert new List<VF_Check__c>{ vfA, vfB, vfC };

        Test.startTest();
        triggerFlow(buyer, 'PENDING');
        Test.stopTest();

        Map<Id, VF_Check__c> results = new Map<Id, VF_Check__c>(
            [SELECT Status__c FROM VF_Check__c WHERE Id IN (:vfA.Id, :vfB.Id, :vfC.Id)]
        );
        System.assertEquals('Pending Lender Decision', results.get(vfA.Id).Status__c);
        System.assertEquals('Pending Lender Decision', results.get(vfB.Id).Status__c);
        System.assertEquals('Approved', results.get(vfC.Id).Status__c);
    }
}