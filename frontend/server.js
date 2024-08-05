const express = require('express');
const axios = require('axios');
const path = require('path');

const app = express();
const port = 80;

// Serve static files from the 'public' directory
app.use(express.static('public'));

// Endpoint to retrieve data from another Node.js API
app.get('/data', async (req, res) => {
    try {
        // Make a GET request to the other Node.js API
        const response = await axios.get('http://product-api-service:3000/products');
        // Extract the data from the response
        const data = response.data;
        // Send the data as a JSON response
        res.json(data);
    } catch (error) {
        // Handle any errors that occur during the request
        console.error('Error fetching data:', error.message);
        // Send an error response
        res.status(500).json({ error: 'An error occurred while fetching data' });
    }
});


// Start the server
app.listen(port, () => {
    console.log(`Server listening at http://localhost:${port}`);
});
