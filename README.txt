PROPERTY & UNIT ONBOARDING TOOL

Repository:
https://github.com/ajaved0900/property-unit-onboarding

--------------------------------------------------------------------------

1. PROJECT OVERVIEW

This application is a Ruby on Rails tool that allows internal Customer Success
or Operations users to safely import Properties and their associated Units
from a CSV file.

The system follows a strict Preview -> Finalize workflow to ensure data
integrity. No records are permanently written to the database until validation
is complete and the user confirms the import.

Primary objectives:

- Upload a CSV file
- Display a preview before saving
- Prevent duplicate properties
- Group units under their corresponding property
- Provide a summary after finalizing

--------------------------------------------------------------------------

2. TECH STACK

Ruby 3.x
Rails 7.x
PostgreSQL
Docker and Docker Compose
JSONB (for ImportBatch payload storage)

--------------------------------------------------------------------------

3. DATA MODELS

Property

Columns:
id
name (string)
street_address (string)
city (string)
state (string)
zip_code (string)
created_at
updated_at

Associations:
has_many :units

Rule:
Building name is treated as a case-insensitive unique identifier.


Unit

Columns:
id
property_id
unit_number (string)
created_at
updated_at

Associations:
belongs_to :property

Rule:
Unit number must be unique per property.


ImportBatch

Columns:
id
payload (jsonb)
created_at
updated_at

Purpose:
Stores parsed CSV data during preview so Finalize imports exactly what was
previewed. Prevents session overflow and guarantees consistency.

--------------------------------------------------------------------------

4. EXPECTED CSV FORMAT

Headers (must match exactly):

Building Name
Street Address
Unit
City
State
Zip Code

Example:

Building Name,Street Address,Unit,City,State,Zip Code
Sunset Apartments,123 Main St,1A,Chicago,IL,60601
Sunset Apartments,123 Main St,2B,Chicago,IL,60601

--------------------------------------------------------------------------

5. IMPORT WORKFLOW

STEP 1 - PREVIEW

Controller action: preview

Process:

1. Parse file using:
   CSV.foreach(file.path, headers: true, header_converters: :symbol)

2. Validate each row.
3. Group rows by building_name.
4. Detect duplicate units within the file.
5. Detect existing properties using:
   Property.where("LOWER(name) = ?", building_name.downcase)

6. Store grouped results in ImportBatch as JSON.
7. Render preview page.

Important:
No records are written to properties or units tables during preview.


STEP 2 - FINALIZE

Controller action: finalize

Process:

1. Load ImportBatch payload.
2. For each building:

   property = Property.where("LOWER(name) = ?", name.downcase).first

   If property does not exist:
       Create Property
   Else:
       Reuse existing property

3. For each unit:
   If unit does not exist under property:
       Create unit
   Else:
       Skip

4. Display summary report.

--------------------------------------------------------------------------

6. VALIDATION LOGIC

Required Fields:

Building Name
Street Address
Unit
City
State
Zip Code

If missing:
"Line X: Missing required fields"

ZIP Code Validation:

- Must contain only numeric characters
- Must be at least 5 digits

Valid:
60601
606011234

Invalid:
6060A
1234

State Normalization:

Two-letter abbreviations are converted to full state names.

Examples:
IL -> Illinois
WA -> Washington

Invalid states trigger preview errors.

Duplicate Detection Within CSV:

A unit number may only appear once per building.
Duplicate units within the same building are flagged during preview.

Duplicate Detection Against Database:

Properties are matched case-insensitively:

Property.where("LOWER(name) = ?", building_name.downcase)

If property exists:
- Do not create duplicate property
- Attach units to existing property

--------------------------------------------------------------------------

7. HOW TO RUN LOCALLY (WINDOWS + DOCKER)

Prerequisites:

Install:
Docker Desktop
Git
Visual Studio Code (optional)

Ensure Docker Desktop is running before proceeding.

Clone Repository:

git clone https://github.com/ajaved0900/property-unit-onboarding.git
cd property-unit-onboarding

Start Application:

docker compose up -d --build

Verify Containers:

docker compose ps

Create and Migrate Database:

docker exec -it property_data_retrieval-web-1 ruby bin/rails db:create
docker exec -it property_data_retrieval-web-1 ruby bin/rails db:migrate

Access Application:

Open browser and navigate to:

http://localhost:3000

Usage:

Upload CSV -> Preview -> Finalize

--------------------------------------------------------------------------

8. VERIFY DATABASE CONTENT

Check counts:

docker exec -it property_data_retrieval-web-1 ruby bin/rails runner "puts Property.count"
docker exec -it property_data_retrieval-web-1 ruby bin/rails runner "puts Unit.count"

Open Rails console:

docker exec -it property_data_retrieval-web-1 ruby bin/rails c

Example:

Property.last
Unit.last

Type exit to leave console.

--------------------------------------------------------------------------

9. RESET DATABASE (FOR TESTING)

docker exec -it property_data_retrieval-web-1 ruby bin/rails runner "Unit.delete_all; Property.delete_all; ImportBatch.delete_all"

--------------------------------------------------------------------------

10. ASSUMPTIONS

- Building Name uniquely identifies a property (case-insensitive).
- CSV format is consistent.
- Tool is intended for internal use.
- Data safety is prioritized over performance.

--------------------------------------------------------------------------

11. POTENTIAL IMPROVEMENTS

- Add case-insensitive unique DB index on properties.name
- Add composite unique index on (property_id, unit_number)
- Add import history tracking
- Allow downloadable error CSV
- Move processing to background jobs for large files
- Improve preview UI highlighting
- Support ZIP+4 format (e.g., 60639-1111)

--------------------------------------------------------------------------

12. SUMMARY

This solution demonstrates:

- Safe Preview -> Finalize workflow
- Case-insensitive duplicate protection
- Unit grouping under properties
- Structured validation logic
- Clean Rails architecture focused on correctness
