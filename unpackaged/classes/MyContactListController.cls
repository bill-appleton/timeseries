/** 
 * @description Controller class for managing lists of Contacts, Leads, and custom Adam_Bar__c records.
 */
public class MyContactListController {

    /** 
     * @description Retrieves a list of all Contacts with selected fields.
     * @return List of Contact records.
     */
    public static List<Contact> getContacts() {
        return [Select Id, Name, Email, Title, Phone From Contact LIMIT 100];
    }
    
    /** 
     * @description Retrieves a list of all Leads with selected fields.
     * @return List of Lead records.
     */
    public static List<Lead> getLeads() {
        return [Select Id, Name, Email, Title, Phone From Lead LIMIT 100];
    }
    
    /** 
     * @description Retrieves a list of all Adam_Bar__c records with selected fields.
     * @return List of Adam_Bar__c records.
     */
    public static List<Adam_Bar__c> getAdams() {
        return [Select Id, Name From Adam_Bar__c LIMIT 100];
    }
    
    /** 
     * @description Inserts a new Adam_Bar__c record with a predefined name.
     */
    static void myBar() {
        Adam_Bar__c newBar = new Adam_Bar__c(Name='My New Bar');
        insert newBar;
    }
    
    /** 
     * @description Applies a discount by changing the name of each Adam_Bar__c record in the list to 'fred'.
     * @param books List of Adam_Bar__c records to be updated.
     */
    public static void applyDiscount(Adam_Bar__c[] books) {
        for (Adam_Bar__c b : books) {
            b.Name = 'fred';
        }
    }
    
}

