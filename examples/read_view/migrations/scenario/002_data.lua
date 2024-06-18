local crud = require('crud')

local function up()
    crud.insert_many('customers', {
        { 1, box.NULL, 'Elizabeth', 'Bagnall', 12 },
        { 2, box.NULL, 'Mary', 'Bowman', 46 },
        { 3, box.NULL, 'David', 'Bradley', 33 },
        { 4, box.NULL, 'William', 'Bridgens', 81 },
        { 5, box.NULL, 'Jack', 'Brown', 35 },
        { 6, box.NULL, 'William', 'Long', 25 },
        { 7, box.NULL, 'Elizabeth', 'McArdle', 18 },
        { 8, box.NULL, 'Sophia', 'Mills', 29 },
        { 9, box.NULL, 'Henry', 'Ellison', 60 },
        { 10, box.NULL, 'Charlotte', 'Nadkarni', 40 },
        { 11, box.NULL, 'Joseph', 'Padmore', 52 },
        { 12, box.NULL, 'Olivia', 'Kinsella', 22 },
        { 13, box.NULL, 'Thomas', 'Griffin', 64 },
        { 14, box.NULL, 'Emily', 'Grimshaw', 28 },
        { 15, box.NULL, 'Daniel', 'Joyce', 45 },
        { 16, box.NULL, 'Emma', 'Hodges', 33 },
        { 17, box.NULL, 'Alexander', 'Kinsella', 37 },
        { 18, box.NULL, 'Grace', 'Moon', 19 },
        { 19, box.NULL, 'Michael', 'Pirie', 50 },
        { 20, box.NULL, 'Abigail', 'Gauld', 26 },
        { 21, box.NULL, 'Sophia', 'Garrity', 31 },
        { 22, box.NULL, 'William', 'Norman', 42 },
        { 23, box.NULL, 'Mia', 'Morrison', 25 },
        { 24, box.NULL, 'Ethan', 'Walmsley', 34 },
        { 25, box.NULL, 'Ava', 'Fisher', 23 },
        { 26, box.NULL, 'James', 'Jones', 47 },
        { 27, box.NULL, 'Isabella', 'Garrity', 29 },
        { 28, box.NULL, 'Benjamin', 'Paterson', 38 },
        { 29, box.NULL, 'Chloe', 'Walters', 27 },
        { 30, box.NULL, 'Jacob', 'Wilcox', 49 },
        { 31, box.NULL, 'Liam', 'Sheldrick', 36 },
        { 32, box.NULL, 'Charlotte', 'Griffiths', 30 },
        { 33, box.NULL, 'Logan', 'Watkins', 41 },
        { 34, box.NULL, 'Amelia', 'Ahmed', 24 },
        { 35, box.NULL, 'Mason', 'Evans', 43 },
        { 36, box.NULL, 'Harper', 'Iqbal', 32 },
        { 37, box.NULL, 'Elijah', 'Martin', 48 },
        { 38, box.NULL, 'Avery', 'Murray', 28 },
        { 39, box.NULL, 'Oliver', 'Lowe', 39 },
        { 40, box.NULL, 'Evelyn', 'Mishra', 20 }
    })

    return true
end

return {
    up = {
        scenario = up,
    },
}
