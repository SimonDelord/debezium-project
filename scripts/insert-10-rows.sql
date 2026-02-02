-- Insert 10 rows into truck_locations for MirrorMaker2 testing
-- Make sure you're connected to MySimpleDB_Tsql database first

INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (1, GETUTCDATE(), -23.3610, 119.7310);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (2, GETUTCDATE(), -23.3620, 119.7320);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (3, GETUTCDATE(), -23.3630, 119.7330);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (4, GETUTCDATE(), -23.3640, 119.7340);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (5, GETUTCDATE(), -23.3650, 119.7350);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (6, GETUTCDATE(), -23.3660, 119.7360);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (7, GETUTCDATE(), -23.3670, 119.7370);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (8, GETUTCDATE(), -23.3680, 119.7380);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (9, GETUTCDATE(), -23.3690, 119.7390);
INSERT INTO truck_locations (truck_id, time, latitude, longitude) VALUES (10, GETUTCDATE(), -23.3700, 119.7400);

SELECT COUNT(*) AS total_rows FROM truck_locations;

