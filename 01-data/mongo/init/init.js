// MongoDB Initialization Script
// Path: 01-data/mongo/init/init-mongo.js
//
// This script initializes the MongoDB database with:
// - Replica set configuration (required for transactions)
// - Sample collections
// - Indexes
// - Initial data (optional)

// Note: This script runs only on initial container creation
// MONGO_INITDB_ROOT_USERNAME and MONGO_INITDB_ROOT_PASSWORD are set via environment

print('='.repeat(60));
print('MongoDB Initialization Script');
print('='.repeat(60));
print('');

// Connect to admin database
db = db.getSiblingDB('admin');

print('✓ Connected to admin database');
print('');

// Get database name from environment or use default
const dbName = process.env.MONGO_INITDB_DATABASE || 'app_db';

print(`Creating application database: ${dbName}`);
db = db.getSiblingDB(dbName);

// =============================================================================
// Create Collections
// =============================================================================

print('');
print('Creating collections...');

// Users collection
db.createCollection('users', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['username', 'email', 'createdAt'],
            properties: {
                username: {
                    bsonType: 'string',
                    description: 'Username must be a string and is required'
                },
                email: {
                    bsonType: 'string',
                    pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$',
                    description: 'Email must be a valid email address'
                },
                firstName: {
                    bsonType: 'string',
                    description: 'First name'
                },
                lastName: {
                    bsonType: 'string',
                    description: 'Last name'
                },
                role: {
                    enum: ['admin', 'user', 'guest'],
                    description: 'Role can only be admin, user, or guest'
                },
                active: {
                    bsonType: 'bool',
                    description: 'Active status'
                },
                createdAt: {
                    bsonType: 'date',
                    description: 'Creation timestamp'
                },
                updatedAt: {
                    bsonType: 'date',
                    description: 'Update timestamp'
                }
            }
        }
    }
});
print('✓ Created collection: users');

// Sessions collection
db.createCollection('sessions', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['userId', 'token', 'createdAt', 'expiresAt'],
            properties: {
                userId: {
                    bsonType: 'objectId',
                    description: 'User ID reference'
                },
                token: {
                    bsonType: 'string',
                    description: 'Session token'
                },
                createdAt: {
                    bsonType: 'date',
                    description: 'Session creation time'
                },
                expiresAt: {
                    bsonType: 'date',
                    description: 'Session expiration time'
                }
            }
        }
    }
});
print('✓ Created collection: sessions');

// Logs collection (for application logs)
db.createCollection('logs', {
    timeseries: {
        timeField: 'timestamp',
        metaField: 'metadata',
        granularity: 'seconds'
    }
});
print('✓ Created collection: logs (time-series)');

// Events collection
db.createCollection('events');
print('✓ Created collection: events');

// =============================================================================
// Create Indexes
// =============================================================================

print('');
print('Creating indexes...');

// Users indexes
db.users.createIndex({ username: 1 }, { unique: true });
print('✓ Created unique index on users.username');

db.users.createIndex({ email: 1 }, { unique: true });
print('✓ Created unique index on users.email');

db.users.createIndex({ createdAt: 1 });
print('✓ Created index on users.createdAt');

db.users.createIndex({ role: 1, active: 1 });
print('✓ Created compound index on users.role and users.active');

// Sessions indexes
db.sessions.createIndex({ token: 1 }, { unique: true });
print('✓ Created unique index on sessions.token');

db.sessions.createIndex({ userId: 1 });
print('✓ Created index on sessions.userId');

db.sessions.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0 });
print('✓ Created TTL index on sessions.expiresAt');

// Events indexes
db.events.createIndex({ timestamp: -1 });
print('✓ Created index on events.timestamp');

db.events.createIndex({ type: 1, timestamp: -1 });
print('✓ Created compound index on events.type and events.timestamp');

// =============================================================================
// Insert Sample Data (Optional)
// =============================================================================

print('');
print('Inserting sample data...');

// Sample admin user
const adminUser = {
    username: 'admin',
    email: 'admin@example.com',
    firstName: 'Admin',
    lastName: 'User',
    role: 'admin',
    active: true,
    createdAt: new Date(),
    updatedAt: new Date()
};

try {
    db.users.insertOne(adminUser);
    print('✓ Created sample admin user');
} catch (e) {
    if (e.code === 11000) {
        print('⚠ Admin user already exists, skipping');
    } else {
        throw e;
    }
}

// Sample regular user
const regularUser = {
    username: 'user',
    email: 'user@example.com',
    firstName: 'Regular',
    lastName: 'User',
    role: 'user',
    active: true,
    createdAt: new Date(),
    updatedAt: new Date()
};

try {
    db.users.insertOne(regularUser);
    print('✓ Created sample regular user');
} catch (e) {
    if (e.code === 11000) {
        print('⚠ Regular user already exists, skipping');
    } else {
        throw e;
    }
}

// Sample event
db.events.insertOne({
    type: 'system',
    action: 'database_initialized',
    timestamp: new Date(),
    metadata: {
        version: '1.0.0',
        environment: 'development'
    }
});
print('✓ Created initialization event');

// =============================================================================
// Initialize Replica Set (for transactions support)
// =============================================================================

print('');
// print('Checking replica set status...');

// // Switch back to admin database
// db = db.getSiblingDB('admin');

// try {
//     const status = rs.status();
//     print('✓ Replica set already initialized');
//     print(`  Replica set name: ${status.set}`);
//     print(`  Members: ${status.members.length}`);
// } catch (e) {
//     if (e.codeName === 'NotYetInitialized' || e.message.includes('no replset config')) {
//         print('⚠ Replica set not initialized');
//         print('  Note: Replica set must be initialized manually after MongoDB starts');
//         print('');
//         print('  Run the following commands after the container is running:');
//         print('  docker exec -it mongodb mongosh -u admin -p password --authenticationDatabase admin');
//         print('  rs.initiate({ _id: "rs0", members: [{ _id: 0, host: "mongodb:27017" }] })');
//         print('');
//         print('  This enables transactions and change streams.');
//     } else {
//         print(`✗ Error checking replica set: ${e.message}`);
//     }
// }

// =============================================================================
// Create Additional Users (Optional)
// =============================================================================

print('');
print('Creating application users...');

// Application read-write user
try {
    db.createUser({
        user: 'app_user',
        pwd: 'app_password_change_me',  // Change this!
        roles: [
            {
                role: 'readWrite',
                db: dbName
            }
        ]
    });
    print('✓ Created app_user with readWrite role');
} catch (e) {
    if (e.codeName === 'DuplicateKey') {
        print('⚠ app_user already exists, skipping');
    } else {
        print(`✗ Error creating app_user: ${e.message}`);
    }
}

// Application read-only user
try {
    db.createUser({
        user: 'app_readonly',
        pwd: 'readonly_password_change_me',  // Change this!
        roles: [
            {
                role: 'read',
                db: dbName
            }
        ]
    });
    print('✓ Created app_readonly with read role');
} catch (e) {
    if (e.codeName === 'DuplicateKey') {
        print('⚠ app_readonly already exists, skipping');
    } else {
        print(`✗ Error creating app_readonly: ${e.message}`);
    }
}

// =============================================================================
// Summary
// =============================================================================

print('');
print('='.repeat(60));
print('MongoDB Initialization Complete');
print('='.repeat(60));
print('');

// Switch to application database
db = db.getSiblingDB(dbName);

// Print database stats
const stats = db.stats();
print('Database Statistics:');
print(`  Database: ${dbName}`);
print(`  Collections: ${stats.collections}`);
print(`  Indexes: ${stats.indexes}`);
print(`  Data size: ${(stats.dataSize / 1024 / 1024).toFixed(2)} MB`);
print(`  Storage size: ${(stats.storageSize / 1024 / 1024).toFixed(2)} MB`);
print('');

// List collections
print('Collections created:');
db.getCollectionNames().forEach(name => {
    const count = db.getCollection(name).countDocuments();
    print(`  • ${name} (${count} documents)`);
});
print('');

print('Next steps:');
print('  1. Initialize replica set (see instructions above)');
print('  2. Change default passwords for app_user and app_readonly');
print('  3. Update application connection strings');
print('  4. Test database connectivity');
print('');
print('Connection strings:');
print(`  Admin: mongodb://admin:password@mongodb:27017/${dbName}?authSource=admin`);
print(`  App: mongodb://app_user:password@mongodb:27017/${dbName}?authSource=admin`);
print(`  Readonly: mongodb://app_readonly:password@mongodb:27017/${dbName}?authSource=admin`);
print('');
print('✓ Initialization script completed successfully');