// Combat Game - Multi-Map Obstacle Rendere
// Refactored with Game class to manage all game state

// Global game instance
Game game;

// Processing setup function
void setup() {
  size(800, 600);
  game = new Game();
  game.initialize();
}

// Processing draw function
void draw() {
  game.update();
  game.render();
}

// Processing key event handlers
void keyPressed() {
  game.handleKeyPressed();
}

void keyReleased() {
  game.handleKeyReleased();
}

// Interfaces for game functionality
interface BulletCreator {
  void createBullet(float x, float y, float angle, int playerId);
}

interface ObstacleProvider {
  ArrayList<Obstacle> getCurrentObstacles();
}

interface PlayerProvider {
  Player getPlayerByID(int id);
}

// Main Game class - contains all game state and logic
class Game implements BulletCreator, ObstacleProvider, PlayerProvider {
  // Key state tracking
  private boolean[] keys = new boolean[256];
  private boolean[] keyCodes = new boolean[256];

  // Map and game state
  private JSONObject[] mapData = new JSONObject[3];
  private ArrayList<Obstacle> currentObstacles;
  private ArrayList<Bullet> bullets;
  private int currentMap = 0;
  private boolean mapsLoaded = false;

  private String[] mapFiles = {"map1_crossroads.json", "map2_fortress.json", "map3_maze.json"};
  private String[] mapNames = new String[3];
  private String[] mapDescriptions = new String[3];

  private String mapFileBasePath = "/home/raylok/projects/study/desenvolvimento-de-games/projeto-2/processing-combat/";

  // Player instances
  private Player player1, player2;

  public Game() {
    // Constructor - initialize collections
    bullets = new ArrayList<Bullet>();
  }

  public void initialize() {
    // Load all maps from files
    loadAllMaps();
    
    // Start with first map if loading was successful
    if (mapsLoaded) {
      loadMap(currentMap);
      println("Combat Arena Ready!");
      println("Current Map: " + mapNames[currentMap]);
      println("Use number keys 1-3 to switch maps");
      println("Player 1: WASD to move, SPACE to shoot");
      println("Player 2: Arrow keys to move, ENTER to shoot");
    } else {
      println("ERROR: Could not load map files!");
      println("Make sure the following files are in your data folder:");
      for (String filename : mapFiles) {
        println("  - " + filename);
      }
    }
  }

  public void update() {
    if (!mapsLoaded) return;
    
    // Update bullets
    updateBullets();
    
    // Handle movement keys
    handleMovementKeys();
  }

  public void render() {
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
    
    // Render bullets
    renderBullets();
    
    // Render players
    renderPlayers();
    
    // Display UI
    drawUI();
  }

  private void loadAllMaps() {
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

  private void loadMap(int mapIndex) {
    if (!mapsLoaded || mapIndex < 0 || mapIndex >= mapData.length) {
      return;
    }

    try {
      // Load obstacles from JSON and convert to Obstacle objects
      JSONArray obstaclesArray = mapData[mapIndex].getJSONArray("obstacles");
      currentObstacles = new ArrayList<Obstacle>();
      for (int i = 0; i < obstaclesArray.size(); i++) {
        JSONObject obj = obstaclesArray.getJSONObject(i);
        String kind = obj.getString("kind").toLowerCase();
        if (kind.equals("rectangle")) {
          JSONObject center = obj.getJSONObject("center");
          JSONObject measures = obj.getJSONObject("measures");
          currentObstacles.add(new RectangleObstacle(
            center.getFloat("x"),
            center.getFloat("y"),
            measures.getFloat("width"),
            measures.getFloat("height")
          ));
        } else if (kind.equals("sphere")) {
          JSONObject center = obj.getJSONObject("center");
          currentObstacles.add(new SphereObstacle(
            center.getFloat("x"),
            center.getFloat("y"),
            obj.getFloat("radius")
          ));
        } else if (kind.equals("triangle")) {
          JSONArray vertices = obj.getJSONArray("vertices");
          if (vertices.size() >= 3) {
            JSONObject v1 = vertices.getJSONObject(0);
            JSONObject v2 = vertices.getJSONObject(1);
            JSONObject v3 = vertices.getJSONObject(2);
            currentObstacles.add(new TriangleObstacle(
              v1.getFloat("x"), v1.getFloat("y"),
              v2.getFloat("x"), v2.getFloat("y"),
              v3.getFloat("x"), v3.getFloat("y")
            ));
          }
        }
      }
      JSONArray currentPlayers = mapData[mapIndex].getJSONArray("players");

      // Validate players array
      if (currentPlayers.size() != 2) {
        println("WARNING: Map " + mapNames[mapIndex] + " should have exactly 2 players, found " + currentPlayers.size());
      }

      // Create Player instances from JSON data
      createPlayersFromJSON(currentPlayers);

      println("Loaded map: " + mapNames[mapIndex] + " (" + currentObstacles.size() + " obstacles, " + currentPlayers.size() + " players)");
    } catch (Exception e) {
      println("Error loading map " + mapIndex + ": " + e.getMessage());
    }
  }

  private void renderObstacles() {
    if (currentObstacles == null) return;
    
    // Set obstacle appearance based on current map
    setObstacleStyle(currentMap);
    
    // Get the style colors for the obstacles
    color currentFill = g.fillColor;
    color currentStroke = g.strokeColor;
    
    // Loop through each obstacle and render using their display method
    for (Obstacle obstacle : currentObstacles) {
      obstacle.setStyle(currentFill, currentStroke);
      obstacle.display();
    }
  }

  private void setObstacleStyle(int mapIndex) {
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

  private void createPlayersFromJSON(JSONArray players) {
    if (players == null || players.size() < 2) {
      println("Error: Not enough player data in JSON");
      return;
    }

    // Create Player 1
    JSONObject p1Data = players.getJSONObject(0);
    JSONObject p1Pos = p1Data.getJSONObject("position");
    player1 = new Player(
      this,
      this,
      this,
      p1Data.getInt("id"),
      p1Pos.getFloat("x"),
      p1Pos.getFloat("y"),
      p1Data.getFloat("orientation")
    );

    // Create Player 2
    JSONObject p2Data = players.getJSONObject(1);
    JSONObject p2Pos = p2Data.getJSONObject("position");
    player2 = new Player(
      this,
      this,
      this,
      p2Data.getInt("id"),
      p2Pos.getFloat("x"),
      p2Pos.getFloat("y"),
      p2Data.getFloat("orientation")
    );
  }

  private void renderPlayers() {
    if (player1 != null) {
      player1.display();
    }
    if (player2 != null) {
      player2.display();
    }
  }

  private void drawUI() {
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

  private void drawErrorScreen() {
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

  public void handleKeyPressed() {
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

  public void handleKeyReleased() {
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
  private void handleSinglePressKeys() {
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

    // Shooting controls
    if (key == ' ') { // Spacebar for Player 1
      if (player1 != null) {
        player1.shoot();
      }
    }
    
    if (keyCode == ENTER) { // Enter key for Player 2
      if (player2 != null) {
        player2.shoot();
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
          Obstacle obstacle = currentObstacles.get(i);
          println("  " + i + ": " + obstacle.getKind());
        }
        if (player1 != null && player2 != null) {
          println("  Player 1: (" + player1.getX() + ", " + player1.getY() + ") facing " + player1.getOrientation() + "°");
          println("  Player 2: (" + player2.getX() + ", " + player2.getY() + ") facing " + player2.getOrientation() + "°");
        }
        println("Active bullets: " + bullets.size());
      }
    }
  }

  // Call this in your main update loop to handle continuous movement
  private void handleMovementKeys() {
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

  // Helper functions to check key states
  public boolean isKeyPressed(char k) {
    return keys[k];
  }

  public boolean isKeyCodePressed(int code) {
    return keyCodes[code];
  }

  // Bullet management functions
  private void updateBullets() {
    for (int i = bullets.size() - 1; i >= 0; i--) {
      Bullet bullet = bullets.get(i);
      bullet.update();

      // Remove bullet if it's out of bounds or hit something
      if (bullet.shouldRemove()) {
        bullets.remove(i);
      }
    }
  }

  private void renderBullets() {
    for (Bullet bullet : bullets) {
      bullet.display();
    }
  }

  public void createBullet(float x, float y, float angle, int playerId) {
    bullets.add(new Bullet(this, this, x, y, angle, playerId));
  }

  // Getters for game state (used by Player and Bullet classes)
  public ArrayList<Obstacle> getCurrentObstacles() {
    return currentObstacles;
  }

  public Player getPlayerByID(int id) {
    if (id == 1) {
      return player1;
    } else if (id == 2) {
      return player2;
    }
    return null;
  }
}

// Bullet class - now takes Game reference
class Bullet {
  private ObstacleProvider obstacleProvider;
  private PlayerProvider playerProvider;
  private float x, y;
  private float angle;
  private float speed = 4.0; // Slightly faster than player speed
  private int playerId;
  private boolean shouldRemove = false;
  private float size = 6; // Small square bullet
  private SphereCollider collider; // Use sphere collider for bullets

  public Bullet(ObstacleProvider obstacleProvider, PlayerProvider playerProvider, float startX, float startY, float angle, int playerId) {
    this.obstacleProvider = obstacleProvider;
    this.playerProvider = playerProvider;
    this.x = startX;
    this.y = startY;
    this.angle = angle;
    this.playerId = playerId;
    this.collider = new SphereCollider(x, y, size/2); // Radius is half the size
  }

  public void update() {
    // Move bullet
    x += cos(radians(angle)) * speed;
    y += sin(radians(angle)) * speed;
    
    // Update collider position
    collider.updatePosition(x, y);
    
    // Check bounds
    if (x < 20 || x > width - 20 || y < 20 || y > height - 20) {
      shouldRemove = true;
      return;
    }
    
    // Check collision with players using colliders
    Player player1 = playerProvider.getPlayerByID(1);
    Player player2 = playerProvider.getPlayerByID(2);
    
    if (player1 != null && playerId != 1) {
      if (collider.isCollidingWith(player1.getCollider())) {
        println("Player 1 hit by Player " + playerId + "'s bullet!");
        shouldRemove = true;
        return;
      }
    }
    
    if (player2 != null && playerId != 2) {
      if (collider.isCollidingWith(player2.getCollider())) {
        println("Player 2 hit by Player " + playerId + "'s bullet!");
        shouldRemove = true;
        return;
      }
    }
    
    // Check collision with obstacles using colliders
    ArrayList<Obstacle> currentObstacles = obstacleProvider.getCurrentObstacles();
    if (currentObstacles != null) {
      for (Obstacle obstacle : currentObstacles) {
        if (obstacle.isCollidingWith(x, y, size)) {
          shouldRemove = true;
          return;
        }
      }
    }
  }

  public void display() {
    // Set bullet color based on which player fired it
    if (playerId == 1) {
      fill(255, 200, 200); // Light red for Player 1
      stroke(255, 100, 100);
    } else {
      fill(200, 200, 255); // Light blue for Player 2
      stroke(100, 100, 255);
    }
    
    strokeWeight(1);
    rectMode(CENTER);
    
    // Draw bullet as small rotated square
    pushMatrix();
    translate(x, y);
    rotate(radians(angle + 45)); // Rotate 45 degrees for diamond shape
    rect(0, 0, size, size);
    popMatrix();
  }

  public boolean shouldRemove() {
    return shouldRemove;
  }

  public SphereCollider getCollider() {
    return collider;
  }
}

// Player class - now takes Game reference
class Player {
  private BulletCreator bulletCreator;
  private ObstacleProvider obstacleProvider;
  private PlayerProvider playerProvider;
  private int id;
  private float x, y;
  private float orientation;
  private float speed = 2.0;
  private float rotationSpeed = 3.0;
  final private float size = 20; // Tank size (square)
  private int shootCooldown = 0; // Cooldown timer for shooting
  private final int maxShootCooldown = 15; // Frames between shots
  private RectangleCollider collider; // Use rectangle collider for players

  Player(BulletCreator bulletCreator, ObstacleProvider obstacleProvider, PlayerProvider playerProvider, int id, float x, float y, float orientation) {
    this.bulletCreator = bulletCreator;
    this.obstacleProvider = obstacleProvider;
    this.playerProvider = playerProvider;
    this.id = id;
    this.x = x;
    this.y = y;
    this.orientation = orientation;
    this.collider = new RectangleCollider(x, y, size, size);
  }

  public void display() {
    // Update cooldown
    if (shootCooldown > 0) {
      shootCooldown--;
    }
    
    // Set player colors
    if (id == 1) {
      fill(255, 100, 100); // Red for Player 1
      stroke(255, 150, 150);
    } else {
      fill(100, 100, 255); // Blue for Player 2
      stroke(150, 150, 255);
    }

    strokeWeight(2);

    // Draw tank body (square)
    pushMatrix();
    translate(x, y);
    rotate(radians(orientation));

    rectMode(CENTER);
    rect(0, 0, size, size);

    // Draw tank barrel (line extending forward)
    stroke(255, 255, 255);
    strokeWeight(3);
    line(0, 0, 15, 0);

    popMatrix();

    // Draw player label
    fill(255, 255, 255);
    textAlign(CENTER);
    textSize(10);
    text("P" + id, x, y - 25);

    // Draw orientation indicator (small arrow)
    fill(255, 255, 0);
    noStroke();
    pushMatrix();
    translate(x, y);
    rotate(radians(orientation));
    triangle(18, 0, 12, -3, 12, 3);
    popMatrix();

    // Draw cooldown indicator
    if (shootCooldown > 0) {
      stroke(255, 255, 0);
      strokeWeight(2);
      noFill();
      float cooldownAngle = map(shootCooldown, 0, maxShootCooldown, 0, TWO_PI);
      arc(x, y, size + 8, size + 8, -PI/2, -PI/2 + cooldownAngle);
    }

    // Debug: Draw hitbox outline (optional - comment out if not needed)
    drawHitbox();
  }

  // Draw hitbox for debugging purposes
  public void drawHitbox() {
    stroke(255, 255, 0);
    strokeWeight(1);
    noFill();
    rectMode(CENTER);
    rect(x, y, size, size);
  }

  // Check collision with another player using colliders
  public boolean isCollidingWith(Player other) {
    if (other == null) return false;
    return collider.isCollidingWith(other.getCollider());
  }

  public void shoot() {
    if (shootCooldown <= 0) {
      // Calculate bullet spawn position (slightly in front of tank)
      float bulletX = x + cos(radians(orientation)) * (size/2 + 5);
      float bulletY = y + sin(radians(orientation)) * (size/2 + 5);
      
      bulletCreator.createBullet(bulletX, bulletY, orientation, id);
      shootCooldown = maxShootCooldown;
    }
  }

  public void moveForward() {
    float dx = cos(radians(orientation)) * speed;
    float dy = sin(radians(orientation)) * speed;

    // Calculate new position
    float newX = x + dx;
    float newY = y + dy;

    // Check arena bounds
    if (newX > 30 + size/2 && newX < width - 30 - size/2 &&
        newY > 30 + size/2 && newY < height - 30 - size/2) {

      // Temporarily move to check collisions
      float oldX = x, oldY = y;
      x = newX;
      y = newY;
      collider.updatePosition(x, y);

      // Check for collisions
      if (!hasCollisions()) {
        // No collision, keep new position
      } else {
        // Collision detected, revert position
        x = oldX;
        y = oldY;
        collider.updatePosition(x, y);
      }
    }
  }

  public void moveBackward() {
    float dx = cos(radians(orientation)) * speed;
    float dy = sin(radians(orientation)) * speed;

    // Calculate new position
    float newX = x - dx;
    float newY = y - dy;

    // Check arena bounds
    if (newX > 30 + size/2 && newX < width - 30 - size/2 &&
        newY > 30 + size/2 && newY < height - 30 - size/2) {

      // Temporarily move to check collisions
      float oldX = x, oldY = y;
      x = newX;
      y = newY;
      collider.updatePosition(x, y);

      // Check for collisions
      if (!hasCollisions()) {
        // No collision, keep new position
      } else {
        // Collision detected, revert position
        x = oldX;
        y = oldY;
        collider.updatePosition(x, y);
      }
    }
  }

  // Check if tank has any collisions using colliders
  private boolean hasCollisions() {
    // Check collision with other player
    Player player1 = playerProvider.getPlayerByID(1);
    Player player2 = playerProvider.getPlayerByID(2);
    Player otherPlayer = (this == player1) ? player2 : player1;
    if (isCollidingWith(otherPlayer)) {
      return true;
    }

    // Check collision with obstacles using colliders
    ArrayList<Obstacle> currentObstacles = obstacleProvider.getCurrentObstacles();
    if (currentObstacles != null) {
      for (int i = 0; i < currentObstacles.size(); i++) {
        Obstacle obstacle = currentObstacles.get(i);
        if (obstacle.isCollidingWith(this)) {
          return true;
        }
      }
    }

    return false;
  }

  public void rotateLeft() {
    orientation -= rotationSpeed;
  }

  public void rotateRight() {
    orientation += rotationSpeed;
  }

  // Getters for accessing position, size, and collider
  public float getX() { return x; }
  public float getY() { return y; }
  public float getSize() { return size; }
  public float getOrientation() { return orientation; }
  public RectangleCollider getCollider() { return collider; }
}

// Base Collider class - handles collision detection logic
abstract class Collider {
  protected String type;

  public Collider(String type) {
    this.type = type;
  }

  public abstract boolean isCollidingWith(float x, float y, float size);
  public abstract boolean isCollidingWith(Player player);
  public abstract boolean isCollidingWith(Collider other);
  public abstract void updatePosition(float... params);

  public String getType() {
    return type;
  }
}

// Rectangle Collider
class RectangleCollider extends Collider {
  private float x, y, width, height;

  public RectangleCollider(float x, float y, float width, float height) {
    super("rectangle");
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  // Update position - params: newX, newY
  public void updatePosition(float... params) {
    if (params.length >= 2) {
      this.x = params[0];
      this.y = params[1];
    }
  }

  // Update size - useful for dynamic obstacles
  public void updateSize(float newWidth, float newHeight) {
    this.width = newWidth;
    this.height = newHeight;
  }

  public boolean isCollidingWith(Player player) {
    return isCollidingWith(player.getX(), player.getY(), player.getSize());
  }
  public boolean isCollidingWith(float px, float py, float playerSize) {
    // AABB collision detection
    return (px - playerSize/2 < x + width/2 &&
            px + playerSize/2 > x - width/2 &&
            py - playerSize/2 < y + height/2 &&
            py + playerSize/2 > y - height/2);
  }

  public boolean isCollidingWith(Collider other) {
    if (other instanceof RectangleCollider) {
      RectangleCollider rect = (RectangleCollider) other;
      return (x - width/2 < rect.x + rect.width/2 &&
              x + width/2 > rect.x - rect.width/2 &&
              y - height/2 < rect.y + rect.height/2 &&
              y + height/2 > rect.y - rect.height/2);
    } else if (other instanceof SphereCollider) {
      SphereCollider sphere = (SphereCollider) other;
      // Rectangle-circle collision
      float closestX = constrain(sphere.x, x - width/2, x + width/2);
      float closestY = constrain(sphere.y, y - height/2, y + height/2);
      float distance = dist(sphere.x, sphere.y, closestX, closestY);
      return distance <= sphere.radius;
    }
    return false;
  }

  // Getters for position and size
  public float getX() { return x; }
  public float getY() { return y; }
  public float getWidth() { return width; }
  public float getHeight() { return height; }
}

// Sphere Collider
class SphereCollider extends Collider {
  private float x, y, radius;

  public SphereCollider(float x, float y, float radius) {
    super("sphere");
    this.x = x;
    this.y = y;
    this.radius = radius;
  }

  // Update position - params: newX, newY
  public void updatePosition(float... params) {
    if (params.length >= 2) {
      this.x = params[0];
      this.y = params[1];
    }
  }

  // Update radius - useful for dynamic obstacles
  public void updateRadius(float newRadius) {
    this.radius = newRadius;
  }

  public boolean isCollidingWith(Player player) {
    return isCollidingWith(player.getX(), player.getY(), player.getSize());
  }

  public boolean isCollidingWith(float px, float py, float playerSize) {
    float distance = dist(px, py, x, y);
    return distance < (playerSize/2 + radius);
  }

  public boolean isCollidingWith(Collider other) {
    if (other instanceof SphereCollider) {
      SphereCollider sphere = (SphereCollider) other;
      float distance = dist(x, y, sphere.x, sphere.y);
      return distance < (radius + sphere.radius);
    } else if (other instanceof RectangleCollider) {
      RectangleCollider rect = (RectangleCollider) other;
      // Circle-rectangle collision
      float closestX = constrain(x, rect.x - rect.width/2, rect.x + rect.width/2);
      float closestY = constrain(y, rect.y - rect.height/2, rect.y + rect.height/2);
      float distance = dist(x, y, closestX, closestY);
      return distance <= radius;
    }
    return false;
  }

  // Getters for position and radius
  public float getX() { return x; }
  public float getY() { return y; }
  public float getRadius() { return radius; }
}

// Triangle Collider
class TriangleCollider extends Collider {
  private float x1, y1, x2, y2, x3, y3;

  public TriangleCollider(float x1, float y1, float x2, float y2, float x3, float y3) {
    super("triangle");
    this.x1 = x1;
    this.y1 = y1;
    this.x2 = x2;
    this.y2 = y2;
    this.x3 = x3;
    this.y3 = y3;
  }

  // Update position - params: x1, y1, x2, y2, x3, y3
  public void updatePosition(float... params) {
    if (params.length >= 6) {
      this.x1 = params[0];
      this.y1 = params[1];
      this.x2 = params[2];
      this.y2 = params[3];
      this.x3 = params[4];
      this.y3 = params[5];
    }
  }

  public boolean isCollidingWith(Player player) {
    return isCollidingWith(player.getX(), player.getY(), player.getSize());
  }

  public boolean isCollidingWith(float px, float py, float playerSize) {
    float playerRadius = playerSize / 2;
    
    // First check if player center is inside triangle
    if (isPointInTriangle(px, py)) {
      return true;
    }
    
    // Check distance to each edge of the triangle
    float dist1 = distancePointToLineSegment(px, py, x1, y1, x2, y2);
    float dist2 = distancePointToLineSegment(px, py, x2, y2, x3, y3);
    float dist3 = distancePointToLineSegment(px, py, x3, y3, x1, y1);
    
    float minDistanceToEdge = min(dist1, min(dist2, dist3));
    
    return minDistanceToEdge <= playerRadius;
  }

  public boolean isCollidingWith(Collider other) {
    if (other instanceof SphereCollider) {
      SphereCollider sphere = (SphereCollider) other;
      return isCollidingWith(sphere.x, sphere.y, sphere.radius * 2);
    } else if (other instanceof RectangleCollider) {
      RectangleCollider rect = (RectangleCollider) other;
      // Check if any corner of rectangle is inside triangle or if triangle intersects rectangle
      return isCollidingWith(rect.x, rect.y, sqrt(rect.width*rect.width + rect.height*rect.height));
    }
    return false;
  }

  // Check if a point is inside the triangle using barycentric coordinates
  private boolean isPointInTriangle(float px, float py) {
    float denom = (y2 - y3) * (x1 - x3) + (x3 - x2) * (y1 - y3);
    if (abs(denom) < 0.001) return false; // Degenerate triangle
    
    float a = ((y2 - y3) * (px - x3) + (x3 - x2) * (py - y3)) / denom;
    float b = ((y3 - y1) * (px - x3) + (x1 - x3) * (py - y3)) / denom;
    float c = 1 - a - b;
    
    return a >= 0 && b >= 0 && c >= 0;
  }

  // Calculate distance from point to line segment
  private float distancePointToLineSegment(float px, float py, float x1, float y1, float x2, float y2) {
    float dx = x2 - x1;
    float dy = y2 - y1;
    float lengthSquared = dx * dx + dy * dy;
    
    if (lengthSquared == 0) {
      // Line segment is actually a point
      return dist(px, py, x1, y1);
    }
    
    // Calculate parameter t for projection of point onto line
    float t = ((px - x1) * dx + (py - y1) * dy) / lengthSquared;
    
    // Clamp t to [0, 1] to stay within line segment
    t = constrain(t, 0, 1);

    // Find closest point on line segment
    float closestX = x1 + t * dx;
    float closestY = y1 + t * dy;

    return dist(px, py, closestX, closestY);
  }

  // Getters for vertices
  public float getX1() { return x1; }
  public float getY1() { return y1; }
  public float getX2() { return x2; }
  public float getY2() { return y2; }
  public float getX3() { return x3; }
  public float getY3() { return y3; }
}

// Base Obstacle class - now uses composition with Collider
abstract class Obstacle {
  protected String kind;
  protected color fillColor;
  protected color strokeColor;
  protected float strokeWeight;
  protected Collider collider;

  public Obstacle(String kind, Collider collider) {
    this.kind = kind;
    this.collider = collider;
    this.strokeWeight = 2;
  }

  public void setStyle(color fillColor, color strokeColor) {
    this.fillColor = fillColor;
    this.strokeColor = strokeColor;
  }

  public abstract void display();

  public boolean isCollidingWith(Player player) {
    return collider.isCollidingWith(player);
  }

  public boolean isCollidingWith(float x, float y, float size) {
    return collider.isCollidingWith(x, y, size);
  }

  public String getKind() {
    return kind;
  }
}

// Rectangle Obstacle - simplified, uses RectangleCollider
class RectangleObstacle extends Obstacle {
  private float x, y;
  private float width, height;

  public RectangleObstacle(float x, float y, float width, float height) {
    super("rectangle", new RectangleCollider(x, y, width, height));
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  public void display() {
    fill(fillColor);
    stroke(strokeColor);
    strokeWeight(this.strokeWeight);
    rectMode(CENTER);
    rect(x, y, width, height);
  }
}

// Sphere Obstacle - simplified, uses SphereCollider
class SphereObstacle extends Obstacle {
  private float x, y;
  private float radius;

  public SphereObstacle(float x, float y, float radius) {
    super("sphere", new SphereCollider(x, y, radius));
    this.x = x;
    this.y = y;
    this.radius = radius;
  }

  public void display() {
    fill(fillColor);
    stroke(strokeColor);
    strokeWeight(this.strokeWeight);
    ellipse(x, y, radius * 2, radius * 2);
  }
}

// Triangle Obstacle - simplified, uses TriangleCollider
class TriangleObstacle extends Obstacle {
  private float x1, y1, x2, y2, x3, y3;

  public TriangleObstacle(float x1, float y1, float x2, float y2, float x3, float y3) {
    super("triangle", new TriangleCollider(x1, y1, x2, y2, x3, y3));
    this.x1 = x1;
    this.y1 = y1;
    this.x2 = x2;
    this.y2 = y2;
    this.x3 = x3;
    this.y3 = y3;
  }

  public void display() {
    fill(fillColor);
    stroke(strokeColor);
    strokeWeight(this.strokeWeight);
    triangle(x1, y1, x2, y2, x3, y3);
  }
}
