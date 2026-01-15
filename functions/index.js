const { onCall, HttpsError } = require("firebase-functions/v2/https");
const fetch = require("node-fetch");

/**
 * Cloud Function proxy for Google Directions API.
 * This bypasses CORS restrictions for web clients.
 *
 * The API key should be in the .env file as GOOGLE_MAPS_API_KEY
 */
exports.getDirections = onCall(
    {
        // Allow unauthenticated access (anyone can call this function)
        invoker: "public",
        // Enable CORS for web clients
        cors: true,
    },
    async (request) => {
        try {
            const { origin, destination, waypoints, mode } = request.data;

            // Validate required parameters
            if (!origin || !destination) {
                throw new HttpsError(
                    "invalid-argument",
                    "Origin and destination are required"
                );
            }

            // Get API key from environment
            const apiKey = process.env.GOOGLE_MAPS_API_KEY;

            if (!apiKey) {
                throw new HttpsError(
                    "failed-precondition",
                    "Google Maps API key not configured"
                );
            }

            // Try with the requested mode first, then fall back to driving
            const modesToTry = [mode || "bicycling", "driving"];

            for (const tryMode of modesToTry) {
                // Build the Directions API URL
                let url = `https://maps.googleapis.com/maps/api/directions/json?` +
                    `origin=${encodeURIComponent(origin)}` +
                    `&destination=${encodeURIComponent(destination)}` +
                    `&mode=${tryMode}` +
                    `&key=${apiKey}`;

                // Add waypoints if provided
                if (waypoints && waypoints.length > 0) {
                    const waypointStr = waypoints.join("|");
                    url += `&waypoints=${encodeURIComponent(waypointStr)}`;
                }

                console.log(`Trying ${tryMode} mode: origin=${origin}, destination=${destination}, waypoints=${waypoints?.length || 0}`);

                // Make the request to Google Directions API
                const response = await fetch(url);
                const responseData = await response.json();

                if (responseData.status === "OK") {
                    console.log(`Success with ${tryMode} mode`);
                    return {
                        success: true,
                        data: responseData,
                    };
                }

                console.log(`${tryMode} mode returned: ${responseData.status}`);

                // If not ZERO_RESULTS, it's a real error - don't try fallback
                if (responseData.status !== "ZERO_RESULTS") {
                    console.error("Directions API error:", responseData.status, responseData.error_message);
                    return {
                        success: false,
                        status: responseData.status,
                        error: responseData.error_message || "Unknown error",
                    };
                }
            }

            // All modes returned ZERO_RESULTS
            return {
                success: false,
                status: "ZERO_RESULTS",
                error: "No route found between these points",
            };
        } catch (error) {
            console.error("getDirections error:", error);
            throw new HttpsError("internal", error.message);
        }
    });
