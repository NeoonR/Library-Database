USE LibraryDB;
GO
-- Drop tables if they exist
DROP TABLE IF EXISTS Fines;
DROP TABLE IF EXISTS Loans;
DROP TABLE IF EXISTS Copies;
DROP TABLE IF EXISTS BookAuthors;
DROP TABLE IF EXISTS Authors;
DROP TABLE IF EXISTS Books;
DROP TABLE IF EXISTS Publishers;
DROP TABLE IF EXISTS Members;
GO
-- Members
CREATE TABLE Members (
    member_id INT PRIMARY KEY,
    first_name VARCHAR(30) NOT NULL,
    last_name VARCHAR(30) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone CHAR(10),
    address VARCHAR(255),
    join_date DATE NOT NULL,
    CONSTRAINT chk_email_format CHECK (email LIKE '%@%.%'),
    CONSTRAINT chk_phone_digits CHECK (phone NOT LIKE '%[^0-9]%')
);

-- Publishers
CREATE TABLE Publishers (
    publisher_id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255)
);

-- Books
CREATE TABLE Books (
    book_id INT PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    isbn CHAR(13) UNIQUE NOT NULL,
    publication_year INT CHECK (publication_year BETWEEN 300 AND YEAR(GETDATE())),
    publisher_id INT,
    FOREIGN KEY (publisher_id) REFERENCES Publishers(publisher_id)
);

-- Authors
CREATE TABLE Authors (
    author_id INT PRIMARY KEY,
    first_name VARCHAR(30) NOT NULL,
    last_name VARCHAR(30) NOT NULL
);

-- BookAuthors (many-to-many)
CREATE TABLE BookAuthors (
    book_id INT,
    author_id INT,
    PRIMARY KEY (book_id, author_id),
    FOREIGN KEY (book_id) REFERENCES Books(book_id),
    FOREIGN KEY (author_id) REFERENCES Authors(author_id)
);

-- Copies
CREATE TABLE Copies (
    copy_id INT PRIMARY KEY,
    book_id INT NOT NULL,
    acquisition_date DATE NOT NULL,
    status VARCHAR(20) CHECK (status IN ('Available', 'Borrowed', 'Lost', 'Damaged')),
    FOREIGN KEY (book_id) REFERENCES Books(book_id)
);
GO
--default constraint
ALTER TABLE Copies
ADD CONSTRAINT DF_Copies_Status DEFAULT 'Available' FOR status;
GO

-- Loans
CREATE TABLE Loans (
    loan_id INT PRIMARY KEY,
    member_id INT NOT NULL,
    copy_id INT NOT NULL,
    loan_date DATE NOT NULL,
    due_date DATE NOT NULL,
    return_date DATE,
    FOREIGN KEY (member_id) REFERENCES Members(member_id),
    FOREIGN KEY (copy_id) REFERENCES Copies(copy_id),
    CONSTRAINT chk_loan_dates CHECK (return_date IS NULL OR return_date >= loan_date)
);

-- Fines
CREATE TABLE Fines (
    fine_id INT PRIMARY KEY,
    loan_id INT UNIQUE NOT NULL,
    amount DECIMAL(6,2) CHECK (amount >= 0),
    paid BIT DEFAULT 0,
    FOREIGN KEY (loan_id) REFERENCES Loans(loan_id)
);

-- Indexes
CREATE INDEX idx_members_email ON Members(email);
CREATE INDEX idx_books_title ON Books(title);
CREATE INDEX idx_loans_due_date ON Loans(due_date);
CREATE INDEX idx_copies_status ON Copies(status);
CREATE INDEX idx_bookauthors_book ON BookAuthors(book_id);
CREATE INDEX idx_bookauthors_author ON BookAuthors(author_id);
CREATE INDEX idx_loans_member ON Loans(member_id);
CREATE INDEX idx_copies_book ON Copies(book_id);
CREATE INDEX idx_fines_loan ON Fines(loan_id);
GO
-- Members
INSERT INTO Members VALUES
(1, 'Alice', 'Johnson', 'alice@example.com', '1234567890', '12 Maria St.', '2025-01-10'),
(2, 'Bob', 'Smith', 'bob@example.com', '0987654321', '456 Okopowa St.', '2025-02-20'),
(3, 'Carol', 'Davis', 'carol@example.com', '1112223333', '789 Park Ave.', '2025-03-05'),
(4, 'David', 'Miller', 'david@example.com', '2223334444', '101 Main St.', '2025-03-10'),
(5, 'Eve', 'Clark', 'eve@example.com', '3334445555', '23 Elm St.', '2025-04-01'),
(6, 'Frank', 'Wright', 'frank@example.com', '4445556666', '78 River Rd.', '2025-04-20');

-- Publishers
INSERT INTO Publishers VALUES
(1, 'Gnome Press', 'New York, NY'),
(2, 'Secker & Warburg', 'London, UK'),
(3, 'Penguin Books', 'London, UK'),
(4, 'HarperCollins', 'New York, NY');

-- Books
INSERT INTO Books VALUES
(101, '1984', '9780133970777', 2020, 2),
(102, 'I, Robot', '9780195153446', 2021, 1),
(103, 'Brave New World', '9780060850524', 2019, 3),
(104, 'The Hobbit', '9780007525492', 2022, 4),
(105, 'Foundation', '9780553293357', 2020, 1),
(106, 'Animal Farm', '9780451526342', 2018, 2);

-- Authors
INSERT INTO Authors VALUES
(1, 'George', 'Orwell'),
(2, 'Isaac', 'Asimov'),
(3, 'Aldous', 'Huxley'),
(4, 'J.R.R.', 'Tolkien');

-- BookAuthors
INSERT INTO BookAuthors VALUES
(101, 1),
(102, 2),
(103, 3),
(104, 4),
(105, 2),
(106, 1);

-- Copies
INSERT INTO Copies VALUES
(1001, 101, '2023-01-01', 'Available'),
(1002, 101, '2023-02-15', 'Borrowed'),
(1003, 102, '2023-03-10', 'Available'),
(1004, 103, '2023-04-01', 'Borrowed'),
(1005, 104, '2023-04-15', 'Available'),
(1006, 105, '2023-04-20', 'Borrowed'),
(1007, 106, '2023-05-01', 'Borrowed');

-- Loans
INSERT INTO Loans VALUES
	(201, 1, 1002, '2025-05-01', '2025-05-15', NULL),         -- Active
	(202, 2, 1004, '2025-05-05', '2025-05-20', '2025-05-18'), -- Returned
	(203, 3, 1006, '2025-05-10', '2025-05-25', NULL),         -- Active
	(204, 4, 1007, '2025-05-15', '2025-05-30', NULL),         -- Active
	(205, 5, 1001, '2025-05-02', '2025-05-16', '2025-05-10');-- Returned
-- Fines
INSERT INTO Fines (fine_id, loan_id, amount, paid)
SELECT 
		ROW_NUMBER() OVER (ORDER BY L.loan_id) + ISNULL((SELECT MAX(fine_id) FROM Fines), 0) AS fine_id,
		L.loan_id,
		DATEDIFF(DAY, L.due_date, ISNULL(L.return_date, GETDATE())) * 1.0 AS amount,
		0 -- unpaid
	FROM Loans L
	WHERE 
		(
			(L.return_date IS NOT NULL AND L.return_date > L.due_date)
			OR 
			(L.return_date IS NULL AND GETDATE() > L.due_date)
		)
		AND NOT EXISTS (
			SELECT 1 FROM Fines F WHERE F.loan_id = L.loan_id
		);
GO
-- Drop and create views
IF OBJECT_ID('View_BooksWithDetails', 'V') IS NOT NULL
    DROP VIEW View_BooksWithDetails;
GO

CREATE VIEW View_BooksWithDetails AS
SELECT 
    B.book_id,
    B.title,
    B.publication_year,
    CONCAT(A.first_name, ' ', A.last_name) AS author_name,
    P.name AS publisher_name
	FROM Books B
	JOIN BookAuthors BA ON B.book_id = BA.book_id
	JOIN Authors A ON BA.author_id = A.author_id
	JOIN Publishers P ON B.publisher_id = P.publisher_id;
GO

IF OBJECT_ID('View_MemberCurrentActivity') IS NOT NULL
    DROP VIEW View_MemberCurrentActivity;
GO

CREATE VIEW View_MemberCurrentActivity AS
SELECT 
    M.member_id,
    CONCAT(M.first_name, ' ', M.last_name) AS full_name,
	M.phone,
    M.address,
    (
        SELECT COUNT(*)
        FROM Loans L
        WHERE L.member_id = M.member_id AND L.return_date IS NULL
    ) AS current_loans,
    ISNULL((
        SELECT STRING_AGG(B.title, ', ')
        FROM Loans L
        JOIN Copies C ON L.copy_id = C.copy_id
        JOIN Books B ON C.book_id = B.book_id
        WHERE L.member_id = M.member_id AND L.return_date IS NULL
    ), '0') AS borrowed_books FROM Members M;
GO

IF OBJECT_ID('View_OnlyActiveLoans') IS NOT NULL
    DROP VIEW View_OnlyActiveLoans;
GO

CREATE VIEW View_OnlyActiveLoans AS
SELECT 
    M.member_id,
    CONCAT(M.first_name, ' ', M.last_name) AS full_name,
    M.phone,
    M.email,
    M.address,
    COUNT(L.loan_id) AS current_loans,
    MIN(L.loan_date) AS oldest_loan_date,
    STRING_AGG(B.title, ', ') AS borrowed_books,
    STRING_AGG(CONVERT(VARCHAR, L.due_date, 23), ', ') AS due_dates,
    ISNULL(SUM(CASE WHEN F.paid = 0 THEN F.amount ELSE 0 END), 0) AS total_unpaid_fines
	FROM Members M
	JOIN Loans L ON M.member_id = L.member_id
	JOIN Copies C ON L.copy_id = C.copy_id
	JOIN Books B ON C.book_id = B.book_id
	LEFT JOIN Fines F ON L.loan_id = F.loan_id
	WHERE L.return_date IS NULL
	GROUP BY M.member_id, M.first_name, M.last_name, M.phone, M.email, M.address;
GO
IF OBJECT_ID('View_LoanAndReturnHistory') IS NOT NULL
	DROP VIEW View_LoanAndReturnHistory;
GO
CREATE VIEW View_LoanAndReturnHistory AS
SELECT 
    L.loan_id,
    M.member_id,
    CONCAT(M.first_name, ' ', M.last_name) AS member_name,
    B.title,
    L.loan_date AS last_date,
    'Loaned' AS last_event
FROM Loans L
JOIN Members M ON L.member_id = M.member_id
JOIN Copies C ON L.copy_id = C.copy_id
JOIN Books B ON C.book_id = B.book_id

UNION

SELECT 
    L.loan_id,
    M.member_id,
    CONCAT(M.first_name, ' ', M.last_name) AS member_name,
    B.title,
    L.return_date AS last_date,
    'Returned' AS last_event
FROM Loans L
JOIN Members M ON L.member_id = M.member_id
JOIN Copies C ON L.copy_id = C.copy_id
JOIN Books B ON C.book_id = B.book_id
WHERE L.return_date IS NOT NULL;
GO
-- View results
SELECT * FROM View_OnlyActiveLoans;
SELECT * FROM View_BooksWithDetails;
SELECT * FROM View_MemberCurrentActivity;
SELECT * FROM View_LoanAndReturnHistory;
GO
-- Set book copy as 'Available' when returned
CREATE TRIGGER trg_UpdateCopyStatusOnReturn
ON Loans
AFTER UPDATE
AS
BEGIN
    IF UPDATE(return_date)
    BEGIN
        UPDATE Copies
        SET status = 'Available'
        WHERE copy_id IN (
            SELECT i.copy_id
            FROM inserted i
            WHERE i.return_date IS NOT NULL
        );
    END
END;
GO

-- Prevent deleting a member who still has active loans
CREATE TRIGGER trg_PreventMemberDeleteWithActiveLoans
ON Members
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN Loans l ON l.member_id = d.member_id
        WHERE l.return_date IS NULL
    )
    BEGIN
        RAISERROR('Cannot delete member with active loans.', 16, 1);
        RETURN;
    END

    DELETE FROM Members
    WHERE member_id IN (SELECT member_id FROM deleted);
END;
GO

-- Automatically create a fine when a book is returned late
CREATE TRIGGER trg_AutoCreateFineOnLateReturn
ON Loans
AFTER UPDATE
AS
BEGIN
    INSERT INTO Fines (fine_id, loan_id, amount, paid)
    SELECT 
        ISNULL((SELECT MAX(fine_id) FROM Fines), 300) + ROW_NUMBER() OVER (ORDER BY i.loan_id),
        i.loan_id,
        DATEDIFF(DAY, i.due_date, i.return_date),
        0
    FROM inserted i
    LEFT JOIN Fines f ON f.loan_id = i.loan_id
    WHERE 
        i.return_date IS NOT NULL AND
        i.return_date > i.due_date AND
        f.loan_id IS NULL;
END;
GO
CREATE TRIGGER trg_BlockLoansForHighFines
ON Loans
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN (
            SELECT member_id, SUM(amount) AS total_unpaid
            FROM Loans l
            JOIN Fines f ON l.loan_id = f.loan_id
            WHERE f.paid = 0
            GROUP BY member_id
        ) fine_summary ON fine_summary.member_id = i.member_id
        WHERE fine_summary.total_unpaid >= 30
    )
    BEGIN
        RAISERROR('This member has $30 or more in unpaid fines. Cannot borrow more books.', 16, 1);
        ROLLBACK;
        RETURN;
    END

    -- Proceed with insert if the fine limit is not reached
    INSERT INTO Loans (loan_id, member_id, copy_id, loan_date, due_date, return_date)
    SELECT loan_id, member_id, copy_id, loan_date, due_date, return_date
    FROM inserted;
END;
GO

-- Get unique book publication years
SELECT DISTINCT publication_year
FROM Books;
GO

--MIN, MAX, AVG: Find the earliest, latest publication year and average publication year of books
SELECT 
    MIN(publication_year) AS EarliestYear,
    MAX(publication_year) AS LatestYear,
    AVG(publication_year) AS AvgYear
FROM Books;
GO

--Count how many copies are currently available
SELECT COUNT(*) AS AvailableCopies
FROM Copies
WHERE status = 'Available';
GO

--Find authors with more than 1 book in the library
SELECT 
    A.author_id,
    CONCAT(A.first_name, ' ', A.last_name) AS AuthorName,
    COUNT(BA.book_id) AS BookCount
FROM Authors A
JOIN BookAuthors BA ON A.author_id = BA.author_id
GROUP BY A.author_id, A.first_name, A.last_name
HAVING COUNT(BA.book_id) > 1;
GO

-- Show top 3 members with the most current loans
SELECT TOP 3 
    M.member_id,
    CONCAT(M.first_name, ' ', M.last_name) AS FullName,
    COUNT(L.loan_id) AS CurrentLoans
FROM Members M
JOIN Loans L ON M.member_id = L.member_id
WHERE L.return_date IS NULL
GROUP BY M.member_id, M.first_name, M.last_name
ORDER BY CurrentLoans DESC;
GO

--list members who currently have at least one overdue loan
SELECT 
    M.member_id,
    CONCAT(M.first_name, ' ', M.last_name) AS FullName
FROM Members M
WHERE EXISTS (
    SELECT 1 FROM Loans L
    WHERE L.member_id = M.member_id
      AND L.return_date IS NULL
      AND L.due_date < GETDATE()
);
GO

--Show each book's availability status as a label
SELECT 
    B.book_id,
    B.title,
    CASE 
        WHEN EXISTS (SELECT 1 FROM Copies C WHERE C.book_id = B.book_id AND C.status = 'Available') THEN 'Available'
        WHEN EXISTS (SELECT 1 FROM Copies C WHERE C.book_id = B.book_id AND C.status = 'Borrowed') THEN 'Borrowed'
        ELSE 'Not Available'
    END AS AvailabilityStatus
FROM Books B;
GO
CREATE ROLE db_reader;
CREATE ROLE db_writer;
CREATE ROLE librarian;
CREATE ROLE admin_manager;

-- 2. Create SQL Users and Logins (replace passwords)
-- Reader user
CREATE LOGIN user_reader WITH PASSWORD = 'reader123';
CREATE USER user_reader FOR LOGIN user_reader;
EXEC sp_addrolemember 'db_reader', 'user_reader';

-- Writer user
CREATE LOGIN user_writer WITH PASSWORD = 'writer123';
CREATE USER user_writer FOR LOGIN user_writer;
EXEC sp_addrolemember 'db_writer', 'user_writer';

-- Librarian user
CREATE LOGIN user_librarian WITH PASSWORD = 'librarian123';
CREATE USER user_librarian FOR LOGIN user_librarian;
EXEC sp_addrolemember 'librarian', 'user_librarian';

-- Admin user
CREATE LOGIN user_admin WITH PASSWORD = 'admin123';
CREATE USER user_admin FOR LOGIN user_admin;
EXEC sp_addrolemember 'admin_manager', 'user_admin';
GO

-- 3. Grant Permissions to Roles

-- db_reader: read-only on all tables
GRANT SELECT ON SCHEMA::dbo TO db_reader;
GO

-- db_writer: can modify Loans and Fines
GRANT SELECT, INSERT, UPDATE, DELETE ON Loans TO db_writer;
GRANT SELECT, INSERT, UPDATE, DELETE ON Fines TO db_writer;
GO

-- librarian: full CRUD on all user-related tables
GRANT SELECT, INSERT, UPDATE, DELETE ON Members TO librarian;
GRANT SELECT, INSERT, UPDATE, DELETE ON Books TO librarian;
GRANT SELECT, INSERT, UPDATE, DELETE ON Authors TO librarian;
GRANT SELECT, INSERT, UPDATE, DELETE ON BookAuthors TO librarian;
GRANT SELECT, INSERT, UPDATE, DELETE ON Publishers TO librarian;
GRANT SELECT, INSERT, UPDATE, DELETE ON Copies TO librarian;
GRANT SELECT, INSERT, UPDATE, DELETE ON Loans TO librarian;
GRANT SELECT, INSERT, UPDATE, DELETE ON Fines TO librarian;
GO

-- admin_manager: full control
GRANT CONTROL ON DATABASE::LibraryDB TO admin_manager;
GO
EXEC sp_help 'Books';
GO
--sp_columns: Lists columns of a table
EXEC sp_helpdb 'LibraryDB';
GO
-- sp_helpindex: Shows indexes on a table
EXEC sp_helpindex 'Loans';
GO
--sp_helpconstraint: Lists all constraints of a table
EXEC sp_helpconstraint 'Copies';
GO
--sp_databases: Lists all databases on the server
EXEC sp_spaceused 'Books';
GO
--sp_tables: Lists all tables in the current database
EXEC sp_tables;
GO
--sp_fkeys: Find foreign keys referencing a tableLoans)
EXEC sp_fkeys @pktable_name = 'Loans';
GO
--ps_depends: Shows objects that depend on a table or view
EXEC sp_depends 'View_OnlyActiveLoans';
GO
-- sp_who2: Shows information about current users(for performance/debugging)
EXEC sp_who2;
GO
--sp_helpuser
EXEC sp_helpuser;
GO
DECLARE @BackupPath NVARCHAR(500) = 'C:\DBBackups\';
DECLARE @DbName SYSNAME = 'LibraryDB';
DECLARE @FileName NVARCHAR(500) = 
    @BackupPath + @DbName + 
    CONVERT(VARCHAR, GETDATE(), 112) + '.bak';

BACKUP DATABASE @DbName
TO DISK = @FileName
WITH INIT, COMPRESSION, NAME = 'LibraryDB Backup';