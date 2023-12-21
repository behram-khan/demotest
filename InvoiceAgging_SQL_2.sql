DECLARE @AccountCurrentDate DATETIME  = CAST('2023-12-28 07:32:16' AS datetime)		
DECLARE @AccountID INT = 26557
DECLARE @Tax VARCHAR(50)  = null
DECLARE @subdomain VARCHAR(50)  =''
DECLARE @IncludePaidInvoices INT = 0

;WITH Payments AS (
						SELECT
								A.CustomerID,
								SUM(AllocationAmount) AS PaymentTotalAmount
								
							FROM 
							(
									SELECT	
										c.CustomerID,
										PaymentDateIssued = (select pay.dateissued from [transaction] pay where pay.transactionid = ta.TransactionIDFK),
										AllocationAmount = ta.AllocationAmount	
									FROM		[Transaction]  t
									INNER JOIN Customer	c on c.CustomerID = t.CustomerIDFK AND c.AccountIDFK = t.AccountIDFK
									INNER JOIN TransactionAllocation ta ON t.AccountIDFK = ta.AccountIDFK AND t.TransactionID = ta.AllocationTransactionIDFK 
									where		t.AccountIDFK = @AccountID
									and			transactionstatuscode not in ('void','draft')
									and			transactiontypecode in ('INV')									 
							) A
							WHERE A.PaymentDateIssued <= @AccountCurrentDate
							GROUP BY A.CustomerID
		)
, InvoiceWithPayments AS 
(
SELECT		A.CustomerID,
			A.CustomerName,
			A.DefaultCurrencyCode,
			A.CurrencyName,
			A.BaseCurrencyDecimals,
			A.TIMEZONE,			
			Sum(TotalAmount) AS TotalAmount,
			Sum([Current]) [Current],
			Sum([1-15 days]) [1-15 days],
			Sum([15-30 days]) [15-30 days],
			Sum([30+ Days]) [30+ days]

			From
			(
			SELECT		Customer.CustomerID,
						Customer.CustomerName,	
						Account.DefaultCurrencyCode,
						ACCOUNT.TIMEZONE,
						CURRENCY.NAME CURRENCYNAME,
						CURRENCY.DECIMALPLACES BaseCurrencyDecimals,	
						TotalAmount = SUM([TRANSACTION].TotalAmount),
						[Current]=(case when datediff(day, [Transaction].DueDate, @AccountCurrentDate) < 1 then sum([TRANSACTION].TotalAmount) - 
							ISNULL((SELECT PaymentTotalAmount FROm Payments WHERE CustomerID = Customer.CustomerID),0.0) else 0.0 end),
					    [1-15 days]=(case when datediff(day, [Transaction].DueDate, @AccountCurrentDate) between 1 and 15 then sum([TRANSACTION].TotalAmount) - 
							ISNULL((SELECT PaymentTotalAmount FROm Payments WHERE CustomerID = Customer.CustomerID),0.0) else 0.0 end),
						[15-30 days]=(case when datediff(day, [Transaction].DueDate, @AccountCurrentDate) between 16 and 30 then sum([TRANSACTION].TotalAmount) - 
							ISNULL((SELECT PaymentTotalAmount FROm Payments WHERE CustomerID = Customer.CustomerID),0.0) else 0.0 end),
						[30+ Days]=(case when datediff(day, [Transaction].DueDate, @AccountCurrentDate) > 30 then sum([TRANSACTION].TotalAmount) - 
							ISNULL((SELECT PaymentTotalAmount FROm Payments WHERE CustomerID = Customer.CustomerID),0.0) else 0.0 end)

			FROM		[Transaction] 
				inner join Customer	on Customer.CustomerID = [Transaction].CustomerIDFK AND CUSTOMER.ACCOUNTIDFK = [TRANSACTION].ACCOUNTIDFK
				inner join Account	on Account.AccountID = [Transaction].AccountIDFK 
				inner join Currency	on Currency.CurrencyCode = Account.DefaultCurrencyCode
			where		account.accountid = @AccountID
			and			transactionstatuscode not in ('void','draft')
			and			transactiontypecode in ('INV')
		    Group by	Customer.CustomerID,
						Customer.CustomerName,
						[Transaction].DueDate,
						Account.DefaultCurrencyCode,
						CURRENCY.NAME,
						CURRENCY.DECIMALPLACES,
						ACCOUNT.TIMEZONE,
						'https://'+@subdomain+'.avaza.com/customer/details/'+CAST(CUSTOMER.CUSTOMERID AS NVARCHAR)
						) A
			Group by	A.CustomerID,
						A.CustomerName, A.DefaultCurrencyCode,
						A.CurrencyName,
						A.BaseCurrencyDecimals,
						A.TIMEZONE
)

Select * from InvoiceWithPayments
WHERE TotalAmount <> [Current] + [1-15 days] + [15-30 days] + [30+ Days]