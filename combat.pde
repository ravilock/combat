// Combat Game - Multi-Map Obstacle Rendere
// Refactored with Game class to manage all game state

import java.time.LocalDateTime;
import processing.sound.*;

// Global game instance
// Global game instance
Game game;
String gameFilesBasePath = "./";

PImage studioLogo;
String gamePhase = "logo"; // Can be: "logo", "story", "game"
int logoDisplayFrames = 180; // Show logo for 3 seconds at 60 FPS
int storyDisplayFrames = 360; // Show story for 6 seconds at 60 FPS
float logoAlpha = 0; // For fade in/out
float storyAlpha = 0; // For fade in/out
boolean backgroundMusicStarted = false;

// Processing setup function
void setup() {
  size(800, 600);
  studioLogo = loadImage(gameFilesBasePath + "campos-de-batalha-logo.png");
  SoundFile ricochetSound = null;
  SoundFile shootSound = null;
  SoundFile explosionSound = null;
  SoundFile gameStartSound = null;
  SoundFile backgroudMusic = null;

  try {
    ricochetSound = new SoundFile(this, gameFilesBasePath + "ricochet.wav");
    shootSound = new SoundFile(this, gameFilesBasePath + "shoot.wav");
    explosionSound = new SoundFile(this, gameFilesBasePath + "explosion.wav");
    gameStartSound = new SoundFile(this, gameFilesBasePath + "gamestart.wav");
    backgroudMusic = new SoundFile(this, gameFilesBasePath + "theme-song.wav");

    println("Sound effects loaded successfully!");
  } catch (Exception e) {
    println("Warning: Could not load sound effects - " + e.getMessage());
    println("Make sure these files exist in your sketch folder:");
    println("  - ricochet.wav");
    println("  - shoot.wav");
    println("  - explosion.wav");
    println("  - gamestart.wav");
  }

  game = new Game(ricochetSound, shootSound, explosionSound, backgroudMusic);
  if (gameStartSound != null) {
      gameStartSound.play();
  }
}
  // Don't initialize game yet - wait for story phase to complete

// Processing draw function
void draw() {
  if (gamePhase.equals("logo") && studioLogo != null && logoDisplayFrames > 0) {
    background(20, 20, 20);
    imageMode(CENTER);

    // Fade in for first 1s, hold, fade out for last 1s
    int fadeFrames = 60;
    if (logoDisplayFrames > 180 - fadeFrames) {
      logoAlpha = map(logoDisplayFrames, 180, 180 - fadeFrames, 0, 255);
    } else if (logoDisplayFrames < fadeFrames) {
      logoAlpha = map(logoDisplayFrames, fadeFrames, 0, 255, 0);
    } else {
      logoAlpha = 255;
    }
    tint(255, logoAlpha);
    image(studioLogo, width/2, height/2, 512, 512);
    noTint();

    logoDisplayFrames--;
    if (logoDisplayFrames == 0) {
      gamePhase = "story"; // Transition to story phase
    }
    return;
  }
  
  if (gamePhase.equals("story") && storyDisplayFrames > 0) {
    background(15, 15, 25); // Slightly different background for story
    
    // Fade in for first 1s, hold, fade out for last 1s
    int fadeFrames = 30; // 0.5 seconds at 60 FPS
    if (storyDisplayFrames > 360 - fadeFrames) {
      storyAlpha = map(storyDisplayFrames, 360, 360 - fadeFrames, 0, 255);
    } else if (storyDisplayFrames < fadeFrames) {
      storyAlpha = map(storyDisplayFrames, fadeFrames, 0, 255, 0);
    } else {
      storyAlpha = 255;
    }
    
    // Draw story text
    fill(255, 255, 200, storyAlpha);
    textAlign(CENTER);
    textSize(16);
    
    String[] storyLines = {
      "Em um futuro próximo, uma guerra global estoura",
      "entre o Brasil e a China. O mundo assiste enquanto",
      "tanques de guerra avançam pelas fronteiras destruídas.",
      "",
      "Você é o piloto de um tanque azul, lutando pelo Brasil.",
      "Seu objetivo é simples: destruir os tanques vermelhos",
      "inimigos antes que eles destruam você.",
      "",
      "A cada inimigo derrotado, um ponto. Quem fizer 5 pontos",
      "primeiro, vence a batalha — e muda o destino da guerra."
    };
    
    float startY = height/2 - (storyLines.length * 20) / 2;
    for (int i = 0; i < storyLines.length; i++) {
      text(storyLines[i], width/2, startY + i * 20);
    }
    
    storyDisplayFrames--;
    if (storyDisplayFrames == 0) {
      gamePhase = "game"; // Transition to game phase
      game.initialize(); // Initialize game when story ends
      // Start background music when game phase begins
      if (!backgroundMusicStarted && game.getBackgroundMusic() != null) {
        game.getBackgroundMusic().loop();
        backgroundMusicStarted = true;
      }
    }
    return;
  }
  
  // Game phase - only update and render if game is initialized
  if (gamePhase.equals("game")) {
    game.update();
    game.render();
  }
}

// Processing key event handlers
void keyPressed() {
  if (gamePhase.equals("game")) {
    game.handleKeyPressed();
  }
}

void keyReleased() {
  if (gamePhase.equals("game")) {
    game.handleKeyReleased();
  }
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

interface ScoreIncreaser {
  void increaseScore(int playerId);
}

interface PlayerHitListener {
  void onPlayerHit(int playerId);
}

// Main Game class - contains all game state and logic
class Game implements BulletCreator, ObstacleProvider, PlayerProvider, ScoreIncreaser, PlayerHitListener {
  // Sound effects
  private SoundFile ricochetSound;
  private SoundFile shootSound;
  private SoundFile explosionSound;
  private SoundFile backgroudMusic;

  // Key state tracking
  private boolean[] keys = new boolean[256];
  private boolean[] keyCodes = new boolean[256];

  // Map and game state
  private JSONObject[] mapData = new JSONObject[3];
  private ArrayList<Obstacle> currentObstacles;
  private ArrayList<Bullet> bullets;
  private int currentMap = 0;
  private boolean mapsLoaded = false;
  private boolean isGameEnded = false;
  private final int maxScore = 5;

  private int[] scores = {0, 0}; // Player scores

  private String[] mapFiles = {"map1_crossroads.json", "map2_fortress.json", "map3_maze.json"};
  private String[] mapNames = new String[3];
  private String[] mapDescriptions = new String[3];

  // Player instances
  private Player player1, player2;

  public Game(SoundFile ricochetSound, SoundFile shootSound, SoundFile explosionSound, SoundFile backgroudMusic) {
    this.ricochetSound = ricochetSound;
    this.shootSound = shootSound;
    this.explosionSound = explosionSound;
    this.backgroudMusic = backgroudMusic;
    // Constructor - initialize collections
    bullets = new ArrayList<Bullet>();
  }

  // Getter for background music
  public SoundFile getBackgroundMusic() {
    return backgroudMusic;
  }

  public void initialize() {
    // Load all maps from files
    loadAllMaps();
    bullets = new ArrayList<Bullet>();
    isGameEnded = false;

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

    // Handle player hit animation
    handlePlayerHitAnimation();
  }

  public void render() {
    background(20, 20, 20);
    
    if (!mapsLoaded) {
      drawErrorScreen();
      return;
    }

    if (isGameEnded) {
      fill(255, 0, 0);
      textAlign(CENTER);
      textSize(32);
      text("GAME OVER", width/2, height/2);
      textSize(24);
      text("Winner: " + (scores[0] >= maxScore ? "Player 1" : "Player 2"), width/2, height/2 + 30);
      textSize(16);
      text("Press 'R' to restart", width/2, height/2 + 60);
      return;
    }

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
        mapData[i] = loadJSONObject(gameFilesBasePath + mapFiles[i]);
        
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
      shootSound,
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
      shootSound,
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

    // Scores
    fill(255);
    textAlign(CENTER);
    textSize(18);
    text("Scores", width/2, 30);
    textSize(14);
    text("Player 1: " + scores[0], width/2 - 50, 50);
    text("Player 2: " + scores[1], width/2 + 50, 50);

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
      text("• " + gameFilesBasePath + mapFiles[i], width/2, height/2 + 30 + i*15);
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
        if (!player1.isOnHitCooldown()) { // Prevent shooting if on hit cooldown
          player1.shoot();
        }
      }
    }
    
    if (keyCode == ENTER) { // Enter key for Player 2
      if (player2 != null) {
        if (!player2.isOnHitCooldown()) { // Prevent shooting if on hit cooldown
          player2.shoot();
        }
      }
    }

    // Debug and utility functions (only trigger once per press)
    if (key == 'r' || key == 'R') {
      println("Reloading all maps...");
      initialize(); // Reinitialize game state
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
      if (player1.isOnHitCooldown()) {
        // If player is on hit cooldown, prevent movement
        return;
      }
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
      if (player2.isOnHitCooldown()) {
        // If player is on hit cooldown, prevent movement
        return;
      }
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

  private void handlePlayerHitAnimation() {
    if (!mapsLoaded) return;
    if (player1 != null) {
      if (player1.isOnHitCooldown()) {
        player1.rotateWithSpeed(12); // Optional: Rotate player 1 slightly to indicate hit
      }
    }

    if (player2 != null) {
      if (player2.isOnHitCooldown()) {
        player2.rotateWithSpeed(12); // Optional: Rotate player 2 slightly to indicate hit
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
    bullets.add(new Bullet(ricochetSound, explosionSound, this, this, this, this, x, y, angle, playerId));
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

  public void increaseScore(int playerId) {
    if (playerId == 1) {
      scores[0]++;
      if (scores[0] >= maxScore) {
        println("Player 1 wins!");
        isGameEnded = true;
      }
    } else if (playerId == 2) {
      scores[1]++;
      if (scores[1] >= maxScore) {
        println("Player 2 wins!");
        isGameEnded = true;
      }
    }
    println("Player " + playerId + " scored! New score: " + scores[playerId - 1]);
  }

  public void onPlayerHit(int playerId) {
    // Handle player hit logic here if needed
    println("Player " + playerId + " was hit!");
    Player player = getPlayerByID(playerId);
    Player otherPlayer = (playerId == 1) ? player2 : player1;
    if (player != null) {
      player.wasHit(); // Set hit state
      // Move both players to random valid locations
      placePlayerRandomly(otherPlayer);
      // Additional logic for hit can be added here
    }
  }

  // Place a player at a random valid location (not colliding with obstacles or other player)
  private void placePlayerRandomly(Player player) {
    int maxTries = 100;
    float margin = 40;
    float size = player.getSize();
    for (int i = 0; i < maxTries; i++) {
      float x = random(margin + size/2, width - margin - size/2);
      float y = random(margin + size/2, height - margin - size/2);
      float orientation = random(0, 360);
      player.setPositionAndOrientation(x, y, orientation);
      // Check for collisions
      boolean collides = false;
      // Check obstacles
      ArrayList<Obstacle> obs = getCurrentObstacles();
      if (obs != null) {
        for (Obstacle o : obs) {
          if (o.isCollidingWith(player)) {
            collides = true;
            break;
          }
        }
      }
      // Check other player
      Player other = (player == player1) ? player2 : player1;
      if (other != null && player.isCollidingWith(other)) {
        collides = true;
      }
      if (!collides) {
        return;
      }
    }
    // If no valid position found after maxTries, do nothing
  }
}

class Bullet {
  private SoundFile ricochetSound;
  private SoundFile explosionSound;
  private ObstacleProvider obstacleProvider;
  private PlayerProvider playerProvider;
  private ScoreIncreaser scoreIncreaser;
  private PlayerHitListener playerHitListener;
  private float x, y;
  private float speed = 4.0; // Vector intensity
  private float vX, vY; // Velocity components
  private LocalDateTime bulletCreationTime;
  private final int maxBulletLifetime = 5; // Maximum lifetime in seconds
  private int playerId;
  private boolean shouldRemove = false;
  private float size = 6; // Small square bullet
  private SphereCollider collider; // Use sphere collider for bullets
  private int bounces = 0; // Track number of bounces
  private final int maxBounces = 4; // Maximum number of bounces allowed

  public Bullet(SoundFile ricochetSound, SoundFile explosionSound, ObstacleProvider obstacleProvider, PlayerProvider playerProvider, ScoreIncreaser scoreIncreaser, PlayerHitListener playerHitListener, float startX, float startY, float angle, int playerId) {
    this.ricochetSound = ricochetSound;
    this.explosionSound = explosionSound;
    this.obstacleProvider = obstacleProvider;
    this.playerProvider = playerProvider;
    this.scoreIncreaser = scoreIncreaser;
    this.playerHitListener = playerHitListener;
    this.x = startX;
    this.y = startY;
    this.playerId = playerId;
    this.collider = new SphereCollider(x, y, size/2); // Radius is half the size
    this.bulletCreationTime = LocalDateTime.now();

    // Calculate velocity components from angle and speed
    this.vX = cos(radians(angle)) * speed;
    this.vY = sin(radians(angle)) * speed;
  }

  public void update() {
    LocalDateTime now = LocalDateTime.now();
    if (bulletCreationTime != null) {
      // Check if bullet has exceeded its lifetime
      long secondsSinceCreation = java.time.Duration.between(bulletCreationTime, now).getSeconds();
      if (secondsSinceCreation > maxBulletLifetime) {
      shouldRemove = true;
      return;
      }
    }
    // Calculate next position using velocity components
    float nextX = x + vX;
    float nextY = y + vY;
    
    // Check bounds and handle bouncing
    boolean bounced = false;
    
    // Check horizontal bounds (left/right walls)
    if (nextX < 20 || nextX > width - 20) {
      if (bounces < maxBounces) {
        vX = -vX; // Reflect velocity horizontally
        bounces++;
        bounced = true;
        if (ricochetSound != null) ricochetSound.play();
        // Ensure bullet stays within bounds
        nextX = constrain(nextX, 20, width - 20);
      } else {
        shouldRemove = true;
        return;
      }
    }

    // Check vertical bounds (top/bottom walls)
    if (nextY < 20 || nextY > height - 20) {
      if (bounces < maxBounces) {
        vY = -vY; // Reflect velocity vertically
        bounces++;
        bounced = true;
        if (ricochetSound != null) ricochetSound.play();
        // Ensure bullet stays within bounds
        nextY = constrain(nextY, 20, height - 20);
      } else {
        shouldRemove = true;
        return;
      }
    }

    // If we bounced off walls, update position and collider, then continue
    if (bounced) {
      x = nextX;
      y = nextY;
      collider.updatePosition(x, y);
      return; // Skip obstacle collision check this frame to avoid getting stuck
    }
    
    // Check collision with obstacles and handle bouncing
    ArrayList<Obstacle> currentObstacles = obstacleProvider.getCurrentObstacles();
    if (currentObstacles != null) {
      for (Obstacle obstacle : currentObstacles) {
        if (obstacle.isCollidingWith(nextX, nextY, size)) {
          if (bounces < maxBounces) {
            // Calculate bounce velocity based on obstacle type
            calculateBounceVelocity(obstacle, nextX, nextY);
            bounces++;
            if (ricochetSound != null) ricochetSound.play();
            
            // Move bullet slightly away from obstacle to prevent getting stuck
            x += vX * 0.5;
            y += vY * 0.5;
            collider.updatePosition(x, y);
          } else {
            shouldRemove = true;
            return;
          }
        }
      }
    }
    
    // Move bullet normally if no collision
    x = nextX;
    y = nextY;
    collider.updatePosition(x, y);
    
    // Check collision with players using colliders
    Player player1 = playerProvider.getPlayerByID(1);
    Player player2 = playerProvider.getPlayerByID(2);
    
    if (player1 != null && playerId != 1) {
      if (collider.isCollidingWith(player1.getCollider())) {
        scoreIncreaser.increaseScore(2); // Player 2 scores
        playerHitListener.onPlayerHit(1); // Notify player hit
        if (explosionSound != null) explosionSound.play();
        shouldRemove = true;
        return;
      }
    }
    
    if (player2 != null && playerId != 2) {
      if (collider.isCollidingWith(player2.getCollider())) {
        scoreIncreaser.increaseScore(1); // Player 1 scores
        playerHitListener.onPlayerHit(2); // Notify player hit
        if (explosionSound != null) explosionSound.play();
        shouldRemove = true;
        return;
      }
    }
  }
  
  // Calculate bounce velocity based on obstacle type and collision point
  private void calculateBounceVelocity(Obstacle obstacle, float bulletX, float bulletY) {
    String obstacleType = obstacle.getKind();
    
    if (obstacleType.equals("rectangle")) {
      RectangleObstacle rect = (RectangleObstacle) obstacle;
      calculateRectangleBounceVelocity(rect, bulletX, bulletY);
    } else if (obstacleType.equals("sphere")) {
      SphereObstacle sphere = (SphereObstacle) obstacle;
      calculateSphereBounceVelocity(sphere, bulletX, bulletY);
    } else {
      // Default: reverse velocity
      vX = -vX;
      vY = -vY;
    }
  }
  
  private void calculateRectangleBounceVelocity(RectangleObstacle rect, float bulletX, float bulletY) {
    // Get rectangle collider for position and size
    RectangleCollider rectCollider = (RectangleCollider) rect.collider;
    float rectX = rectCollider.getX();
    float rectY = rectCollider.getY();
    float rectWidth = rectCollider.getWidth();
    float rectHeight = rectCollider.getHeight();
    
    // Determine which side of rectangle was hit
    float left = rectX - rectWidth/2;
    float right = rectX + rectWidth/2;
    float top = rectY - rectHeight/2;
    float bottom = rectY + rectHeight/2;
    
    // Calculate distances to each edge
    float distToLeft = abs(bulletX - left);
    float distToRight = abs(bulletX - right);
    float distToTop = abs(bulletY - top);
    float distToBottom = abs(bulletY - bottom);
    
    float minDist = min(min(distToLeft, distToRight), min(distToTop, distToBottom));
    
    // Reflect velocity based on closest edge
    if (minDist == distToLeft || minDist == distToRight) {
      // Hit left or right edge - reflect horizontally
      vX = -vX;
    } else {
      // Hit top or bottom edge - reflect vertically
      vY = -vY;
    }
  }
  
  private void calculateSphereBounceVelocity(SphereObstacle sphere, float bulletX, float bulletY) {
    // Get sphere collider for position
    SphereCollider sphereCollider = (SphereCollider) sphere.collider;
    float sphereX = sphereCollider.getX();
    float sphereY = sphereCollider.getY();
    
    // Calculate normal vector from sphere center to bullet
    float normalX = bulletX - sphereX;
    float normalY = bulletY - sphereY;
    
    // Normalize the normal vector
    float normalLength = sqrt(normalX * normalX + normalY * normalY);
    if (normalLength > 0) {
      normalX /= normalLength;
      normalY /= normalLength;
    }
    
    // Reflect velocity using normal: v' = v - 2(v·n)n
    float dotProduct = vX * normalX + vY * normalY;
    vX = vX - 2 * dotProduct * normalX;
    vY = vY - 2 * dotProduct * normalY;
  }

  public void display() {
    // Set bullet color based on which player fired it
    // Dim the color based on number of bounces for visual feedback
    float bouceColorIntensity = map(bounces, 0, maxBounces, 255, 100);
    float timeColorIntensity = map(java.time.Duration.between(bulletCreationTime, LocalDateTime.now()).getSeconds(), 0, maxBulletLifetime, 255, 100);
    
    float colorIntensity = min(bouceColorIntensity, timeColorIntensity);
    
    if (playerId == 1) {
      fill(colorIntensity, colorIntensity * 0.8, colorIntensity * 0.8); // Dimming red for Player 1
      stroke(255, 100, 100);
    } else {
      fill(colorIntensity * 0.8, colorIntensity * 0.8, colorIntensity); // Dimming blue for Player 2
      stroke(100, 100, 255);
    }
    
    strokeWeight(1);
    
    // Draw bullet as circle
    ellipse(x, y, size, size);
    
    // Draw bounce count indicator (small text above bullet)
    if (bounces > 0) {
      fill(255, 255, 0);
      textAlign(CENTER);
      textSize(8);
      text(bounces, x, y - 10);
    }
  }

  public boolean shouldRemove() {
    return shouldRemove;
  }

  public SphereCollider getCollider() {
    return collider;
  }

  // Getter methods for velocity components and speed
  public float getVX() { return vX; }
  public float getVY() { return vY; }
  public float getSpeed() { return speed; }
  public float getCurrentSpeed() { return sqrt(vX * vX + vY * vY); }
}

class Player {
  private SoundFile shootSound;
  private BulletCreator bulletCreator;
  private ObstacleProvider obstacleProvider;
  private PlayerProvider playerProvider;
  private int id;
  private float x, y;
  private float orientation;
  private float vX, vY; // Vector components for movement
  private LocalDateTime lastHitTime;
  private float speed = 2.0;
  private float rotationSpeed = 3.0;
  final private float size = 20; // Tank size (square)
  private LocalDateTime lastShotTime = null; // Track last shot time
  private final int shootCooldownSeconds = 4; // Cooldown in seconds
  private RectangleCollider collider; // Use rectangle collider for players

  Player(SoundFile shootSound, BulletCreator bulletCreator, ObstacleProvider obstacleProvider, PlayerProvider playerProvider, int id, float x, float y, float orientation) {
    this.shootSound = shootSound;
    this.bulletCreator = bulletCreator;
    this.obstacleProvider = obstacleProvider;
    this.playerProvider = playerProvider;
    this.id = id;
    this.x = x;
    this.y = y;
    this.orientation = orientation;
    this.collider = new RectangleCollider(x, y, size, size);
    // Initialize velocity vectors
    updateVelocityVectors();
  }
  // Calculate velocity vector components based on current orientation
  private void updateVelocityVectors() {
    vX = cos(radians(orientation)) * speed;
    vY = sin(radians(orientation)) * speed;
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
    if (lastShotTime != null) {
      float elapsed = java.time.Duration.between(lastShotTime, LocalDateTime.now()).getSeconds();
      if (elapsed < shootCooldownSeconds) {
        stroke(255, 255, 0);
        strokeWeight(2);
        noFill();
        float cooldownAngle = map(elapsed, 0, shootCooldownSeconds, 0, TWO_PI);
        arc(x, y, size + 8, size + 8, -PI/2, -PI/2 + cooldownAngle);
      }
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
    LocalDateTime now = LocalDateTime.now();
    if (lastShotTime == null || java.time.Duration.between(lastShotTime, now).getSeconds() >= shootCooldownSeconds) {
      // Calculate bullet spawn position (slightly in front of tank)
      float bulletX = x + vX * (size/2 + 5) / speed;
      float bulletY = y + vY * (size/2 + 5) / speed;

      bulletCreator.createBullet(bulletX, bulletY, orientation, id);
      if (shootSound != null) shootSound.play();
      lastShotTime = now;
    }
  }

  public void moveForward() {
    // Use pre-calculated velocity components
    float newX = x + vX;
    float newY = y + vY;

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
    // Use pre-calculated velocity components (reversed)
    float newX = x - vX;
    float newY = y - vY;

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

  public boolean isOnHitCooldown() {
    // Check if player is on hit cooldown
    if (lastHitTime == null) return false;
    LocalDateTime now = LocalDateTime.now();
    // Check if the player was hit within the last 3 seconds
    return lastHitTime.isAfter(now.minusSeconds(3));
  }

  public void wasHit() {
    // Handle player being hit (e.g. flash, sound, etc.)
    lastHitTime = LocalDateTime.now();
  }

  public void rotateLeft() {
    this.rotateWithSpeed(-rotationSpeed);
  }

  public void rotateWithSpeed(float speed) {
    orientation += speed;
    // Recalculate velocity vectors when orientation changes
    updateVelocityVectors();
  }

  public void rotateRight() {
    this.rotateWithSpeed(rotationSpeed);
  }

  // Getters for accessing position, size, and collider
  public float getX() { return x; }
  public float getY() { return y; }
  public float getSize() { return size; }
  public float getOrientation() { return orientation; }
  public RectangleCollider getCollider() { return collider; }

  // Set position and orientation (used for random respawn)
  public void setPositionAndOrientation(float x, float y, float orientation) {
    this.x = x;
    this.y = y;
    this.orientation = orientation;
    this.collider.updatePosition(x, y);
    // Update velocity vectors after changing orientation
    updateVelocityVectors();
  }
}

// Collider interface - defines collision detection contract
interface Collider {
  boolean isCollidingWith(Collider other);
  boolean isCollidingWith(float x, float y, float size);
  boolean isCollidingWith(Player player);
  void updatePosition(float... params);
  String getType();
  
  // Visitor pattern methods for type-safe collision detection
  boolean collidesWith(RectangleCollider rect);
  boolean collidesWith(SphereCollider sphere);
}

// Rectangle Collider
class RectangleCollider implements Collider {
  private float x, y, width, height;

  public RectangleCollider(float x, float y, float width, float height) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  public void updatePosition(float... params) {
    if (params.length >= 2) {
      this.x = params[0];
      this.y = params[1];
    }
  }

  public void updateSize(float newWidth, float newHeight) {
    this.width = newWidth;
    this.height = newHeight;
  }

  public boolean isCollidingWith(Player player) {
    return isCollidingWith(player.getX(), player.getY(), player.getSize());
  }

  public boolean isCollidingWith(float px, float py, float playerSize) {
    return (px - playerSize/2 < x + width/2 &&
            px + playerSize/2 > x - width/2 &&
            py - playerSize/2 < y + height/2 &&
            py + playerSize/2 > y - height/2);
  }

  public boolean isCollidingWith(Collider other) {
    return other.collidesWith(this);
  }

  // Visitor pattern implementations
  public boolean collidesWith(RectangleCollider rect) {
    return (x - width/2 < rect.x + rect.width/2 &&
            x + width/2 > rect.x - rect.width/2 &&
            y - height/2 < rect.y + rect.height/2 &&
            y + height/2 > rect.y - rect.height/2);
  }

  public boolean collidesWith(SphereCollider sphere) {
    float closestX = constrain(sphere.getX(), x - width/2, x + width/2);
    float closestY = constrain(sphere.getY(), y - height/2, y + height/2);
    float distance = dist(sphere.getX(), sphere.getY(), closestX, closestY);
    return distance <= sphere.getRadius();
  }

  public String getType() { return "rectangle"; }
  public float getX() { return x; }
  public float getY() { return y; }
  public float getWidth() { return width; }
  public float getHeight() { return height; }
}

// Sphere Collider
class SphereCollider implements Collider {
  private float x, y, radius;

  public SphereCollider(float x, float y, float radius) {
    this.x = x;
    this.y = y;
    this.radius = radius;
  }

  public void updatePosition(float... params) {
    if (params.length >= 2) {
      this.x = params[0];
      this.y = params[1];
    }
  }

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
    return other.collidesWith(this);
  }

  // Visitor pattern implementations
  public boolean collidesWith(RectangleCollider rect) {
    float closestX = constrain(x, rect.getX() - rect.getWidth()/2, rect.getX() + rect.getWidth()/2);
    float closestY = constrain(y, rect.getY() - rect.getHeight()/2, rect.getY() + rect.getHeight()/2);
    float distance = dist(x, y, closestX, closestY);
    return distance <= radius;
  }

  public boolean collidesWith(SphereCollider sphere) {
    float distance = dist(x, y, sphere.x, sphere.y);
    return distance < (radius + sphere.radius);
  }

  public String getType() { return "sphere"; }
  public float getX() { return x; }
  public float getY() { return y; }
  public float getRadius() { return radius; }
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
