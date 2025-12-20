// MongoDB initialization script
// This script creates databases and users for GRC microservices

print('Start MongoDB initialization...');

// Switch to admin database
db = db.getSiblingDB('admin');

// Authenticate as root user
db.auth('admin', 'admin123');

// Create databases
const databases = [
    'grc',
    'notification_grc_db',
    'GRC_USER_SERVICE',
    'GRC_Regulator_Service',
    'grc-kpi'
];

databases.forEach(function(dbName) {
    print('Creating database: ' + dbName);

    // Switch to database
    db = db.getSiblingDB(dbName);

    // Create a collection to initialize the database
    db.createCollection('system_info');

    // Insert initial document
    db.system_info.insertOne({
        initialized_at: new Date(),
        version: '1.0.0',
        platform: 'GRC Microservices'
    });

    print('Database ' + dbName + ' created successfully');
});

// Create application user with read/write permissions on all databases
db = db.getSiblingDB('admin');

db.createUser({
    user: 'grc_user',
    pwd: 'grc_password_2025',
    roles: [
        { role: 'readWrite', db: 'grc' },
        { role: 'readWrite', db: 'notification_grc_db' },
        { role: 'readWrite', db: 'GRC_USER_SERVICE' },
        { role: 'readWrite', db: 'GRC_Regulator_Service' },
        { role: 'readWrite', db: 'grc-kpi' }
    ]
});

print('Application user created successfully');

// Create indexes for performance
print('Creating indexes...');

// GRC database indexes
db = db.getSiblingDB('grc');
db.users.createIndex({ email: 1 }, { unique: true });
db.assessments.createIndex({ created_at: -1 });
db.assessments.createIndex({ status: 1 });
db.risks.createIndex({ severity: 1 });
db.risks.createIndex({ created_at: -1 });

// User service indexes
db = db.getSiblingDB('GRC_USER_SERVICE');
db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ status: 1 });
db.users.createIndex({ created_at: -1 });

// Notification service indexes
db = db.getSiblingDB('notification_grc_db');
db.notifications.createIndex({ user_id: 1 });
db.notifications.createIndex({ created_at: -1 });
db.notifications.createIndex({ read: 1 });

print('Indexes created successfully');
print('MongoDB initialization completed!');
