# Project Background
(To protect business confidentiality, all sensitive information in this project has been anonymized)

GIGI Hardware is a success story in Singapore, growing rapidly to 7 branches and managing over 20,000 unique item codes (SKUs). Because they grew so quickly, they lacked a formal system to track stock. This led to a common retail nightmare. 

### The Mission
The goal of this project is to build a data-driven foundation for GIGI Hardware to automate the most critical inventory decisions: **what to order, when to order, and how much to keep.**

Without a systematic approach, the business faced a "Retail Nightmare":
- **Frozen Capital:** Wasting money and space on items that don't sell.
- **Lost Sales:** Losing customers because items aren't on the shelves.
- **Guesswork:** Not knowing exactly what, when, or how much to order.

The raw data used to design this model is available [here].

The SQL query model for these calculations is available [here]. 

See the model's inventory recommendations [here].

# Data Structure & Initial Checks

RAW data structure seen consists of following attributes: Date_Time, Doc_No, Item_Code, Item_Brand, Item_Description, Qty, Unit_Price, Gross_Total, Discount_Amt, Subtotal. With a total row count of 32,564 records.

<img width="201" height="217" alt="image" src="https://github.com/user-attachments/assets/d1c10bf9-3fc4-46c4-8223-840d3ba300ba" />
