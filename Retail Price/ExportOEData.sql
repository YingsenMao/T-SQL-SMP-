USE [DM_SMP_Pricing]
GO
/****** Object:  StoredProcedure [dbo].[ExportOEData]    Script Date: 9/4/2017 5:51:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Dennis Anglada>
-- Create date: <August 30, 2016>
-- Description:	<Create Motors (AccuPI) OE File>
-- =============================================
ALTER PROCEDURE [dbo].[ExportOEData]
AS
BEGIN
	SET NOCOUNT ON;

DROP TABLE IF EXISTS AccuPI_ExportOE_List;
DROP TABLE IF EXISTS Export_Accupi;

declare @make as nvarchar(150), @min as int, @max as int

	Select T2.Manufacturer, T2.PartNumber, 0 as 'Processed',  (ROW_NUMBER() OVER ( ORDER BY T2.Manufacturer,T2.PartNumber)) AS id
	Into [DM_SMP_Pricing].[dbo].[AccuPI_ExportOE_List]
	From [DM_SMP_Pricing].[dbo].[Build_AccPI_OEList] T2
	Order By 1,2;


	Declare M_Buyers Cursor for

SELECT        Manufacturer, MIN(id) AS MinID, MAX(id) AS MaxID
FROM            AccuPI_ExportOE_List
WHERE        (Processed = 0)
GROUP BY Manufacturer
ORDER BY Manufacturer

  		OPEN M_Buyers
		FETCH NEXT FROM M_Buyers INTO  
		@Make,@min,@max

		WHILE @@FETCH_STATUS = 0
		BEGIN  

INSERT INTO AccuPI_ExportOE_List
                         (Manufacturer, PartNumber, id, Processed )
SELECT        @make AS Expr1, '<' + @make + '>' AS Expr2, id - 1 AS Expr3, 0 as expr4
FROM            (SELECT        MIN(id) AS id
                          FROM            AccuPI_ExportOE_List AS AccuPI_ExportOE_List_1
                          WHERE        (Manufacturer = @Make)) AS MinID

INSERT INTO AccuPI_ExportOE_List
                         (Manufacturer, PartNumber, id, Processed )
SELECT        @make AS Expr1, '</' + @make + '>' AS Expr2, id + 1 AS Expr3, 0 as expr4
FROM            (SELECT        max(id) AS id
                          FROM            AccuPI_ExportOE_List AS AccuPI_ExportOE_List_1
                          WHERE        (Manufacturer = @Make)) AS maxid


			FETCH NEXT FROM M_Buyers INTO  
			@Make,@min,@max
		end

		CLOSE M_Buyers  
		DEALLOCATE M_Buyers


		SELECT Manufacturer, PartNumber, id
		Into Export_Accupi
		FROM     DM_SMP_Pricing.dbo.AccuPI_ExportOE_List
		GROUP BY Manufacturer, PartNumber, id

	drop table [DM_SMP_Pricing].[dbo].[AccuPI_ExportOE_List]
END
