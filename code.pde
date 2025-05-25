// Combat Game - Multi-Map Obstacle Renderer
// Loads maps from external JSON files

// Key state tracking - add these as global variables
boolean[] keys = new boolean[256];  // For regular keys (a-z, 0-9, etc.)
boolean[] keyCodes = new boolean[256];  // For special keys (arrow keys, etc.)

JSONObject[] mapData = new JSONObject[3];
JSONArray currentObstacles;
JSONArray currentPlayers;

int currentMap = 0;
boolean mapsLoaded = false;

String[] mapFiles = {"map1_crossroads.json", "map2_fortress.json", "map3_maze.json"};
String[] mapNames = new String[3];
String[] mapDescriptions = new String[3];

String mapFileBasePath = "/home/raylok/projects/study/desenvolvimento-de-games/projeto-2/processing-combat/";

// Player instances
Player player1, player2;

void setup() {
  size(800, 600);
  
  // Load all maps from files
  loadAllMaps();
  
  // Start with first map if loading was successful
  if (mapsLoaded) {
    loadMap(currentMap);
    println("Combat Arena Ready!");
    println("Current Map: " + mapNames[currentMap]);
    println("Use number keys 1-3 to switch maps");
  } else {
    println("ERROR: Could not load map files!");
    println("Make sure the following files are in your data folder:");
    for (String filename : mapFiles) {
      println("  - " + filename);
    }
  }
}

void draw() {
  background(20, 20, 20);
  
  if (!mapsLoaded) {
    drawErrorScreen();
    return;
  }
  
  // Draw arena border
  stroke(255, 255, 0);
  strokeWeight(4);
  noFill();
  rect(20, 20, width-40, height-40);
  
  // Render current map obstacles
  renderObstacles();
  
  // Render player spawn points
  renderPlayers();
  
  // Display UI
  drawUI();

  // Handle movement keys
  handleMovementKeys();
}

void loadAllMaps() {
  println("Loading maps from files...");
  
  for (int i = 0; i < mapFiles.length; i++) {
    try {
      println("Loading " + mapFiles[i] + "...");
      mapData[i] = loadJSONObject(mapFileBasePath + mapFiles[i]);
      
      if (mapData[i] != null) {
        // Extract map name and description
        mapNames[i] = mapData[i].getString("name");
        mapDescriptions[i] = mapData[i].getString("description");
        println("  ✓ Loaded: " + mapNames[i]);
      } else {
        println("  ✗ Failed to load " + mapFiles[i]);
        return;
      }
    } catch (Exception e) {
      println("  ✗ Error loading " + mapFiles[i] + ": " + e.getMessage());
      return;
    }
  }
  
  mapsLoaded = true;
  println("All maps loaded successfully!");
}

void loadMap(int mapIndex) {
  if (!mapsLoaded || mapIndex < 0 || mapIndex >= mapData.length) {
    return;
  }

  try {
    currentObstacles = mapData[mapIndex].getJSONArray("obstacles");
    currentPlayers = mapData[mapIndex].getJSONArray("players");

    // Validate players array
    if (currentPlayers.size() != 2) {
      println("WARNING: Map " + mapNames[mapIndex] + " should have exactly 2 players, found " + currentPlayers.size());
    }

    // Create Player instances from JSON data
    createPlayersFromJSON();

    println("Loaded map: " + mapNames[mapIndex] + " (" + currentObstacles.size() + " obstacles, " + currentPlayers.size() + " players)");
  } catch (Exception e) {
    println("Error loading map " + mapIndex + ": " + e.getMessage());
  }
}

void renderObstacles() {
  if (currentObstacles == null) return;
  
  // Set obstacle appearance based on current map
  setObstacleStyle(currentMap);
  
  // Loop through each obstacle and render based on type
  for (int i = 0; i < currentObstacles.size(); i++) {
    JSONObject obstacle = currentObstacles.getJSONObject(i);
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

void setObstacleStyle(int mapIndex) {
  strokeWeight(2);
  
  switch(mapIndex) {
    case 0: // Cross Roads - Green
      fill(100, 150, 100);
      stroke(150, 200, 150);
      break;
    case 1: // Fortress - Blue
      fill(100, 100, 150);
      stroke(150, 150, 200);
      break;
    case 2: // Maze Runner - Red
      fill(150, 100, 100);
      stroke(200, 150, 150);
      break;
  }
}

void renderRectangle(JSONObject rect) {
  JSONObject center = rect.getJSONObject("center");
  JSONObject measures = rect.getJSONObject("measures");
  
  float x = center.getFloat("x");
  float y = center.getFloat("y");
  float h = measures.getFloat("height");
  float w = measures.getFloat("with");
  
  rectMode(CENTER);
  rect(x, y, w, h);
}

void renderSphere(JSONObject sphere) {
  JSONObject center = sphere.getJSONObject("center");
  float radius = sphere.getFloat("radius");
  
  float x = center.getFloat("x");
  float y = center.getFloat("y");
  
  ellipse(x, y, radius * 2, radius * 2);
}

void createPlayersFromJSON() {
  if (currentPlayers == null || currentPlayers.size() < 2) {
    println("Error: Not enough player data in JSON");
    return;
  }

  // Create Player 1
  JSONObject p1Data = currentPlayers.getJSONObject(0);
  JSONObject p1Pos = p1Data.getJSONObject("position");
  player1 = new Player(
    p1Data.getInt("id"),
    p1Pos.getFloat("x"),
    p1Pos.getFloat("y"),
    p1Data.getFloat("orientation")
  );

  // Create Player 2
  JSONObject p2Data = currentPlayers.getJSONObject(1);
  JSONObject p2Pos = p2Data.getJSONObject("position");
  player2 = new Player(
    p2Data.getInt("id"),
    p2Pos.getFloat("x"),
    p2Pos.getFloat("y"),
    p2Data.getFloat("orientation")
  );
}

void renderPlayers() {
  if (player1 != null) {
    player1.display();
  }
  if (player2 != null) {
    player2.display();
  }
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
    
    triangle(x1, y1, x2, y2, x3, y3);
  }
}

void drawUI() {
  // Map selection UI
  fill(255, 255, 0);
  textAlign(LEFT);
  textSize(16);
  text("COMBAT ARENA", 30, 50);
  
  textSize(12);
  text("Current Map: " + mapNames[currentMap], 30, 70);
  text("Press 1-3 to switch maps", 30, 85);
  
  // Map list
  textAlign(RIGHT);
  for (int i = 0; i < mapNames.length; i++) {
    if (i == currentMap) {
      fill(255, 255, 0); // Highlight current map
      text("> " + (i+1) + ". " + mapNames[i], width-30, 50 + i*15);
    } else {
      fill(150, 150, 150);
      text((i+1) + ". " + mapNames[i], width-30, 50 + i*15);
    }
  }
  
  // Map description
  fill(200, 200, 200);
  textAlign(CENTER);
  textSize(10);
  text(mapDescriptions[currentMap], width/2, height-45);
  text("Choose your battlefield! Each map offers different tactical challenges.", width/2, height-30);
}

void drawErrorScreen() {
  fill(255, 100, 100);
  textAlign(CENTER);
  textSize(20);
  text("MAP LOADING ERROR", width/2, height/2 - 60);
  
  textSize(14);
  fill(255, 255, 255);
  text("Could not load map files from data folder.", width/2, height/2 - 20);
  text("Make sure these files exist in your sketch's data folder:", width/2, height/2);
  
  textSize(12);
  fill(200, 200, 200);
  for (int i = 0; i < mapFiles.length; i++) {
    text("• " + mapFileBasePath + mapFiles[i], width/2, height/2 + 30 + i*15);
  }
  
  textSize(10);
  fill(150, 150, 150);
  text("Press 'R' to retry loading maps", width/2, height/2 + 100);
}

void keyPressed() {
  // Handle regular keys
  if (key >= 0 && key < 256) {
    keys[key] = true;
  }

  // Handle special keys (arrow keys, etc.)
  if (keyCode >= 0 && keyCode < 256) {
    keyCodes[keyCode] = true;
  }

  // Non-movement keys that should only trigger once
  handleSinglePressKeys();
}

void keyReleased() {
  // Handle regular keys
  if (key >= 0 && key < 256) {
    keys[key] = false;
  }

  // Handle special keys
  if (keyCode >= 0 && keyCode < 256) {
    keyCodes[keyCode] = false;
  }
}


// Handle keys that should only trigger once per press
void handleSinglePressKeys() {
  if (!mapsLoaded) {
    if (key == 'r' || key == 'R') {
      loadAllMaps();
      if (mapsLoaded) {
        loadMap(currentMap);
      }
    }
    return;
  }

  // Map selection (only trigger once per press)
  if (key >= '1' && key <= '3') {
    int newMap = key - '1';
    if (newMap != currentMap) {
      currentMap = newMap;
      loadMap(currentMap);
    }
  }

  // Debug and utility functions (only trigger once per press)
  if (key == 'r' || key == 'R') {
    println("Reloading all maps...");
    loadAllMaps();
    if (mapsLoaded) {
      loadMap(currentMap);
    }
  }

  if (key == 'i' || key == 'I') {
    if (mapsLoaded && currentObstacles != null) {
      println("\n--- Map Debug Info ---");
      println("Current Map: " + mapNames[currentMap]);
      println("Description: " + mapDescriptions[currentMap]);
      println("File: " + mapFiles[currentMap]);
      println("Obstacles: " + currentObstacles.size());
      for (int i = 0; i < currentObstacles.size(); i++) {
        JSONObject obstacle = currentObstacles.getJSONObject(i);
        println("  " + i + ": " + obstacle.getString("kind"));
      }
      println("Players: " + currentPlayers.size());
      if (player1 != null && player2 != null) {
        println("  Player 1: (" + player1.x + ", " + player1.y + ") facing " + player1.orientation + "°");
        println("  Player 2: (" + player2.x + ", " + player2.y + ") facing " + player2.orientation + "°");
      }
    }
  }
}

// Call this in your main draw() loop to handle continuous movement
void handleMovementKeys() {
  if (!mapsLoaded) return;

  // Player 1 controls (WASD) - using lowercase for consistency
  if (player1 != null) {
    if (keys['w'] || keys['W']) {
      player1.moveForward();
    }
    if (keys['s'] || keys['S']) {
      player1.moveBackward();
    }
    if (keys['a'] || keys['A']) {
      player1.rotateLeft();
    }
    if (keys['d'] || keys['D']) {
      player1.rotateRight();
    }
  }

  // Player 2 controls (Arrow keys)
  if (player2 != null) {
    if (keyCodes[UP]) {
      player2.moveForward();
    }
    if (keyCodes[DOWN]) {
      player2.moveBackward();
    }
    if (keyCodes[LEFT]) {
      player2.rotateLeft();
    }
    if (keyCodes[RIGHT]) {
      player2.rotateRight();
    }
  }
}

// Alternative: Helper functions to check key states
boolean isKeyPressed(char k) {
  return keys[k];
}

boolean isKeyCodePressed(int code) {
  return keyCodes[code];
}

// player info

class Player {
  private int id;
  private float x, y;
  private float orientation;
  private float speed = 2.0;
  private float rotationSpeed = 3.0;

  Player(int id, float x, float y, float orientation) {
    this.id = id;
    this.x = x;
    this.y = y;
    this.orientation = orientation;
  }

  public void display() {
    // Set player colors
    if (id == 1) {
      fill(255, 100, 100); // Red for Player 1
      stroke(255, 150, 150);
    } else {
      fill(100, 100, 255); // Blue for Player 2
      stroke(150, 150, 255);
    }

    strokeWeight(2);

    // Draw tank body (rectangle)
    pushMatrix();
    translate(x, y);
    rotate(radians(orientation));

    rectMode(CENTER);
    rect(0, 0, 20, 14);

    // Draw tank barrel (line extending forward)
    stroke(255, 255, 255);
    strokeWeight(3);
    line(0, 0, 15, 0);

    popMatrix();

    // Draw player label
    fill(255, 255, 255);
    textAlign(CENTER);
    textSize(10);
    text("P" + id, x, y - 20);

    // Draw orientation indicator (small arrow)
    fill(255, 255, 0);
    noStroke();
    pushMatrix();
    translate(x, y);
    rotate(radians(orientation));
    triangle(18, 0, 12, -3, 12, 3);
    popMatrix();
  }

  public void moveForward() {
    float dx = cos(radians(orientation)) * speed;
    float dy = sin(radians(orientation)) * speed;

    // Keep players within arena bounds
    float newX = x + dx;
    float newY = y + dy;

    if (newX > 30 && newX < width - 30) {
      x = newX;
    }
    if (newY > 30 && newY < height - 30) {
      y = newY;
    }
  }

  public void moveBackward() {
    float dx = cos(radians(orientation)) * speed;
    float dy = sin(radians(orientation)) * speed;

    // Keep players within arena bounds
    float newX = x - dx;
    float newY = y - dy;

    if (newX > 30 && newX < width - 30) {
      x = newX;
    }
    if (newY > 30 && newY < height - 30) {
      y = newY;
    }
  }

  public void rotateLeft() {
    orientation -= rotationSpeed;
  }

  public void rotateRight() {
    orientation += rotationSpeed;
  }
}
