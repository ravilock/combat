// Combat Game - Obstacle Renderer
// Loads and renders geometric obstacles from JSON file

JSONObject obstacleData;
JSONArray obstacles;

String jsonFilePath = "/home/raylok/projects/study/desenvolvimento-de-games/projeto-2/processing-combat/obstacles.json";

void setup() {
  size(800, 600);
  
  // Load the JSON file (place obstacles.json in the data folder)
  obstacleData = loadJSONObject(jsonFilePath);
  obstacles = obstacleData.getJSONArray("obstacles");
  
  println("Loaded " + obstacles.size() + " obstacles");
}

void draw() {
  background(50, 50, 50); // Dark background like classic Combat
  
  // Draw border/arena walls
  stroke(255);
  strokeWeight(3);
  noFill();
  rect(10, 10, width-20, height-20);
  
  // Render all obstacles
  renderObstacles();
  
  // Display instructions
  fill(255);
  textAlign(LEFT);
  text("Combat Arena - Obstacles Loaded: " + obstacles.size(), 20, height - 20);
}

void renderObstacles() {
  // Set common obstacle appearance
  fill(100, 150, 100); // Green obstacles like classic Combat
  stroke(150, 200, 150);
  strokeWeight(2);
  
  // Loop through each obstacle and render based on type
  for (int i = 0; i < obstacles.size(); i++) {
    JSONObject obstacle = obstacles.getJSONObject(i);
    String kind = obstacle.getString("kind");
    
    switch(kind.toLowerCase()) {
      case "rectangle":
        renderRectangle(obstacle);
        break;
      case "sphere":
        renderSphere(obstacle);
        break;
      case "triangle":
        renderTriangle(obstacle);
        break;
      default:
        println("Unknown obstacle type: " + kind);
    }
  }
}

void renderRectangle(JSONObject rect) {
  JSONObject center = rect.getJSONObject("center");
  JSONObject measures = rect.getJSONObject("measures");
  
  float x = center.getFloat("x");
  float y = center.getFloat("y");
  float h = measures.getFloat("height");
  float w = measures.getFloat("with"); // Note: keeping your original "with" typo
  
  // Draw rectangle centered at the given position
  rectMode(CENTER);
  rect(x, y, w, h);
}

void renderSphere(JSONObject sphere) {
  JSONObject center = sphere.getJSONObject("center");
  float radius = sphere.getFloat("radius");
  
  float x = center.getFloat("x");
  float y = center.getFloat("y");
  
  // Draw circle (sphere in 2D)
  ellipse(x, y, radius * 2, radius * 2);
}

void renderTriangle(JSONObject triangle) {
  JSONArray vertices = triangle.getJSONArray("vertices");
  
  if (vertices.size() >= 3) {
    JSONObject v1 = vertices.getJSONObject(0);
    JSONObject v2 = vertices.getJSONObject(1);
    JSONObject v3 = vertices.getJSONObject(2);
    
    float x1 = v1.getFloat("x");
    float y1 = v1.getFloat("y");
    float x2 = v2.getFloat("x");
    float y2 = v2.getFloat("y");
    float x3 = v3.getFloat("x");
    float y3 = v3.getFloat("y");
    
    // Draw triangle
    triangle(x1, y1, x2, y2, x3, y3);
  }
}

// Helper function to check if obstacles are being rendered correctly
void keyPressed() {
  if (key == 'r' || key == 'R') {
    // Reload the JSON file
    obstacleData = loadJSONObject(jsonFilePath);
    obstacles = obstacleData.getJSONArray("obstacles");
    println("Reloaded obstacles");
  }
  
  if (key == 'd' || key == 'D') {
    // Debug: print obstacle information
    println("\n--- Obstacle Debug Info ---");
    for (int i = 0; i < obstacles.size(); i++) {
      JSONObject obstacle = obstacles.getJSONObject(i);
      println("Obstacle " + i + ": " + obstacle.getString("kind"));
      
      if (obstacle.hasKey("center")) {
        JSONObject center = obstacle.getJSONObject("center");
        println("  Center: (" + center.getFloat("x") + ", " + center.getFloat("y") + ")");
      }
    }
  }
}
