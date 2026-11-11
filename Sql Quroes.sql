Use manufacturing_ops_db; 

1. On-time delivery vs 85% benchmark
SELECT
    COUNT(*)                                              AS Total_Orders,
    SUM(CASE WHEN Late_Completion = 0 THEN 1 ELSE 0 END)  AS On_Time_Orders,
    SUM(CASE WHEN Late_Completion = 1 THEN 1 ELSE 0 END)  AS Late_Orders,
    ROUND(SUM(CASE WHEN Late_Completion = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS On_Time_Rate_Pct,
    85.00                                                 AS Benchmark_Pct,
    ROUND(SUM(CASE WHEN Late_Completion = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) - 85, 2) AS Gap_To_Benchmark_Pts,
    CASE
        WHEN SUM(CASE WHEN Late_Completion = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) >= 85
        THEN 'Meets benchmark'
        ELSE 'Below benchmark'
    END AS Benchmark_Status
FROM production_orders;


 2. Top 10 machines by late orders
SELECT
    m.Machine_ID,
    COUNT(*) AS Total_Orders,
    SUM(p.Late_Completion) AS Late_Orders,
    ROUND(SUM(p.Late_Completion) * 100.0 / COUNT(*), 2) AS Late_Rate_Pct
FROM production_orders p
JOIN machine_master m
    ON p.Machine_ID = m.Machine_ID
GROUP BY m.Machine_ID
ORDER BY Late_Orders DESC
LIMIT 10;


-- 3. Average completion delay by machine tier
SELECT
    m.Machine_Tier,
    COUNT(*) AS Total_Orders,
    ROUND(AVG(p.Completion_Delay_Days), 2) AS Avg_Delay_Days
FROM production_orders p
JOIN machine_master m
    ON p.Machine_ID = m.Machine_ID
GROUP BY m.Machine_Tier
ORDER BY m.Machine_Tier;


-- 4. Top 10 machines by total repair cost
SELECT
    m.Machine_ID,
    m.Machine_Name,
    ROUND(SUM(d.Repair_Cost_INR), 2) AS Total_Repair_Cost
FROM machine_master m
JOIN downtime_maintenance d
    ON d.Machine_ID = m.Machine_ID
GROUP BY m.Machine_ID, m.Machine_Name
ORDER BY Total_Repair_Cost DESC
LIMIT 10;


-- 5. Production cost share by product category
SELECT
    Product_Category,
    ROUND(SUM(Total_Order_Value), 2) AS Total_Production_Cost,
    ROUND(SUM(Total_Order_Value) * 100.0 /
        (SELECT SUM(Total_Order_Value) FROM production_orders), 2) AS Share_Pct
FROM production_orders
GROUP BY Product_Category
ORDER BY Total_Production_Cost DESC;


-- 6. Low-stock items: shortfall vs reorder level
SELECT
    Product_SKU,
    Warehouse_ID,
    Warehouse_Location,
    Stock_On_Hand,
    Reorder_Level,
    Reorder_Level - Stock_On_Hand AS Shortfall
FROM raw_material_inventory
WHERE Stock_On_Hand < Reorder_Level
ORDER BY Shortfall DESC;


-- 7. Average material turnover by material category
-- (screenshot cut off after these lines; the Stock_Status CASE, FROM and GROUP BY are missing)
SELECT
    Material_Category,
    ROUND(AVG(Material_Turnover_Rate), 2) AS Avg_Turnover_Rate,
    ...


-- 8. Downtime by type
SELECT
    downtime_type,
    COUNT(*) AS total_events,
    ROUND(SUM(repair_cost_inr),2) AS Total_repair_cost,
    ROUND(AVG(repair_cost_inr),2) AS AVG_repair_cost
FROM downtime_maintenance
GROUP BY downtime_type
ORDER BY Total_repair_cost DESC;


-- 9. Monthly downtime incidents and repair cost trend
SELECT
    DATE_FORMAT(Downtime_Start, '%Y-%m') AS Downtime_Month,
    COUNT(*) AS Incidents,
    ROUND(SUM(Repair_Cost_INR), 2) AS Total_Repair_Cost,
    ROUND(LEAD(SUM(Repair_Cost_INR)) OVER (ORDER BY DATE_FORMAT(Downtime_Start, '%Y-%m')), 2) AS Next_Month_Repair_Cost
FROM downtime_maintenance
GROUP BY DATE_FORMAT(Downtime_Start, '%Y-%m')
ORDER BY Downtime_Month;


-- 10. Unresolved downtime incidents by plant
SELECT
    Plant_ID,
    COUNT(*) AS Total_Incidents,
    SUM(CASE WHEN Resolved_Flag = 'No' THEN 1 ELSE 0 END) AS Unresolved_Incidents,
    ROUND(SUM(CASE WHEN Resolved_Flag = 'No' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Unresolved_Rate_Pct
FROM downtime_maintenance
GROUP BY Plant_ID
ORDER BY Unresolved_Rate_Pct DESC;


-- 11. Top 10 machines by defect value
SELECT
    m.Machine_ID,
    m.Machine_Name,
    COUNT(*) AS Defect_Records,
    SUM(q.Defect_Qty) AS Total_Defect_Qty,
    ROUND(SUM(q.Defect_Value), 2) AS Total_Defect_Value
FROM quality_defects q
JOIN machine_master m
    ON q.Machine_ID = m.Machine_ID
GROUP BY m.Machine_ID, m.Machine_Name
ORDER BY Total_Defect_Value DESC
LIMIT 10;


-- 12. Defect type breakdown
SELECT
    Defect_Type,
    COUNT(*) AS Defect_Records,
    SUM(Defect_Qty) AS Total_Defect_Qty,
    ROUND(COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM quality_defects), 2) AS Share_Pct
FROM quality_defects
GROUP BY Defect_Type
ORDER BY Defect_Records DESC;


-- 13. Monthly production orders and value
SELECT
    DATE_FORMAT(Order_Date, '%Y-%m') AS Order_Month,
    COUNT(*) AS Orders,
    ROUND(SUM(Total_Order_Value), 2) AS Production_Value
FROM production_orders
WHERE Order_Date IS NOT NULL
GROUP BY DATE_FORMAT(Order_Date, '%Y-%m')
ORDER BY Order_Month;


-- 14. Warehouse stock and stockout risk
SELECT
    Warehouse_ID,
    Warehouse_Location,
    COUNT(*) AS Stock_Records,
    SUM(Stock_On_Hand) AS Total_Stock,
    ROUND(AVG(Stock_On_Hand), 2) AS Avg_Stock,
    COUNT(CASE WHEN Stockout_Risk = 'Yes' THEN 1 END) AS Stockout_Risk_Items,
    COUNT(CASE WHEN Overstock_Risk = 'Yes' THEN 1 END) AS Overstock_Risk_Items,
    ROUND(COUNT(CASE WHEN Stockout_Risk = 'Yes' THEN 1 END) * 100.0 / COUNT(*), 2) AS Stockout_Pct
FROM raw_material_inventory
GROUP BY Warehouse_ID, Warehouse_Location
ORDER BY Stockout_Pct DESC;


-- 15. Machine risk score (OEE, downtime, defects)

SELECT
    m.Machine_ID,
    m.Machine_Name,
    m.Machine_Category,
    m.OEE_Score,
    ROUND(COALESCE(d.Downtime_Hours, 0), 1) AS Downtime_Hours,
    ROUND(COALESCE(q.Defect_Qty, 0) * 100.0 / o.Planned_Qty, 2) AS Defect_Rate_Pct,
    (CASE WHEN m.OEE_Score < 60 THEN 1 ELSE 0 END
   + CASE WHEN COALESCE(d.Downtime_Hours, 0) > 83.6 THEN 1 ELSE 0 END
   + CASE WHEN COALESCE(q.Defect_Qty, 0) * 100.0 / o.Planned_Qty > 0.33 THEN 1 ELSE 0 END) AS Risk_Score
FROM machine_master m
JOIN (SELECT Machine_ID, SUM(Planned_Quantity) AS Planned_Qty
      FROM production_orders GROUP BY Machine_ID) o
    ON o.Machine_ID = m.Machine_ID
LEFT JOIN (SELECT Machine_ID, SUM(Downtime_Duration_Hours) AS Downtime_Hours
           FROM downtime_maintenance GROUP BY Machine_ID) d
    ON d.Machine_ID = m.Machine_ID
LEFT JOIN (SELECT Machine_ID, SUM(Defect_Qty) AS Defect_Qty
           FROM quality_defects GROUP BY Machine_ID) q
    ON q.Machine_ID = m.Machine_ID
GROUP BY m.Machine_ID, m.Machine_Name, m.Machine_Category, m.OEE_Score,