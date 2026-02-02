-- Simple insert of 100 rows into truck_locations
-- Make sure you're connected to MySimpleDB_Tsql database first

DECLARE @counter INT = 1;

WHILE @counter <= 100
BEGIN
    INSERT INTO truck_locations (truck_id, time, latitude, longitude)
    VALUES (
        ((@counter - 1) % 10) + 1,
        GETUTCDATE(),
        -23.3600 + (RAND() * 0.05) - 0.025,
        119.7300 + (RAND() * 0.05) - 0.025
    );
    SET @counter = @counter + 1;
END

SELECT COUNT(*) AS total_rows FROM truck_locations;
