const mongoose = require('mongoose');

const connectDB = async () => {
    try {
        // Debug log to check if MONGODB_URI exists
        if (!process.env.MONGODB_URI) {
            console.error('MONGODB_URI is not defined in environment variables');
            process.exit(1);
        }

        console.log('Attempting to connect to MongoDB...');
        const conn = await mongoose.connect(process.env.MONGODB_URI, {
            // These options are no longer needed in Mongoose 6+, but kept for reference
            // useNewUrlParser: true,
            // useUnifiedTopology: true,
        });

        console.log(`MongoDB Connected: ${conn.connection.host}`);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        console.error('Full error details:', error);
        process.exit(1);
    }
};

module.exports = connectDB; 