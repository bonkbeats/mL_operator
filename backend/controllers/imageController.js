const Image = require('../models/Image');

// Save image metadata
const saveImage = async (req, res) => {
  console.log('Received request to save image metadata');
  try {
    console.log('Authenticated user ID:', req.user._id);
    console.log('Request body:', req.body);
    const { localPath } = req.body;
    
    // Basic validation
    if (!localPath) {
        console.error('Validation Error: localPath is missing');
        return res.status(400).json({ message: 'localPath is required' });
    }

    console.log('Creating new Image document');
    const image = new Image({
      userId: req.user._id,
      localPath
    });
    
    console.log('Saving Image document to MongoDB');
    await image.save();
    console.log('Image document saved successfully:', image);

    console.log('Sending 201 response');
    res.status(201).json(image);
  } catch (error) {
    console.error('Error in saveImage:', error);
    console.log('Sending 500 response');
    res.status(500).json({ message: error.message });
  }
};

// Update image with Supabase URL
const updateImageUrl = async (req, res) => {
  try {
    const { imageId, supabaseUrl } = req.body;
    const image = await Image.findById(imageId);
    if (!image) {
      return res.status(404).json({ message: 'Image not found' });
    }
    image.supabaseUrl = supabaseUrl;
    image.isUploaded = true;
    await image.save();
    res.json(image);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Get user's images
const getUserImages = async (req, res) => {
  console.log('Received request to get user images');
  try {
    console.log('Authenticated user ID:', req.user._id);
    console.log('Fetching images from MongoDB for user:', req.user._id);
    const images = await Image.find({ userId: req.user._id })
      .sort({ createdAt: -1 });
    console.log('Images found:', images.length);

    console.log('Sending 200 response with images');
    res.json(images);
  } catch (error) {
    console.error('Error in getUserImages:', error);
    console.log('Sending 500 response');
    res.status(500).json({ message: error.message });
  }
};

// Delete image
const deleteImage = async (req, res) => {
  try {
    const image = await Image.findById(req.params.id);
    if (!image) {
      return res.status(404).json({ message: 'Image not found' });
    }
    if (image.userId.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Not authorized' });
    }
    await image.remove();
    res.json({ message: 'Image deleted' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Admin function to get all images or images by user
const getAdminImages = async (req, res) => {
  console.log('Received request to get admin images');
  try {
    // Check if a specific userId is requested
    const userId = req.query.userId;
    const filter = userId ? { userId: userId } : {}; // Filter by userId if provided, otherwise get all

    console.log('Fetching images from MongoDB with filter:', filter);
    const images = await Image.find(filter).populate('userId', 'username email') // Populate user info
      .sort({ createdAt: -1 });
    console.log('Images found:', images.length);

    console.log('Sending 200 response with images');
    res.json(images);
  } catch (error) {
    console.error('Error in getAdminImages:', error);
    console.log('Sending 500 response');
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  saveImage,
  updateImageUrl,
  getUserImages,
  deleteImage,
  getAdminImages
}; 