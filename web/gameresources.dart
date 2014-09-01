part of Dark;

Renderers renderers = new Renderers();

class Renderers {
  HashMap<GL.Texture, Sprites> guiSprites = new HashMap<GL.Texture, Sprites>();
  HashMap<GL.Texture, Sprites> spriteMaps = new HashMap<GL.Texture, Sprites>();
  HashMap<GL.Texture, Sprites> transparentSpriteMaps = new HashMap<GL.Texture, Sprites>();
  HashMap<GL.Texture, Walls> walls = new HashMap<GL.Texture, Walls>();
  HashMap<GL.Texture, Walls> transparentMiddleWalls = new HashMap<GL.Texture, Walls>();
  Floors floors;
  
  void addSpriteMap(GL.Texture texture) {
    guiSprites[texture] = new Sprites(spriteShader, texture);
    spriteMaps[texture] = new Sprites(spriteShader, texture);
    transparentSpriteMaps[texture] = new Sprites(transparentSpriteShader, texture);
  }

  void addWallMap(GL.Texture texture) {
    walls[texture] = new Walls(wallShader, texture);
    transparentMiddleWalls[texture] = new Walls(wallShader, texture);
  }

  void setFlatMap(GL.Texture texture) {
    if (floors!=null) {
      throw new StateError("More than one texture atlas for flats!");
    }
    floors = new Floors(floorShader, texture);
  }


  void addMiddleTransparentWall(Image image, InsertWallFunction wallBuilderFunc) {
    transparentMiddleWalls[image.texture].insertWall(wallBuilderFunc);
  }
  
  void addWall(Image image, InsertWallFunction wallBuilderFunc) {
    walls[image.texture].insertWall(wallBuilderFunc);
  }
  
  void addGuiSprite(int x, int y, String imageName) {
    Image image = resources.sprites[imageName];
    guiSprites[image.imageAtlas.texture].insertGuiSprite(x, y, guiSpriteCount++, image);
  }
  
  List<Image> fontChars = new List<Image>(256);

  void addGuiText(int x, int y, String text) {
    for (int i=0; i<text.length; i++) {
      int u = text.codeUnitAt(i)&255;
      Image image = fontChars[u];
      if (image!=null) {
        renderers.guiSprites[image.imageAtlas.texture].insertGuiSprite(x+i*8, y, guiSpriteCount, image);
      }
    }
    guiSpriteCount++;
  }
  
  void prepare() {
    for (int i=0; i<256; i++) {
      String code = i.toString();
      while (code.length<3) code = "0"+code;
      fontChars[i] = resources.sprites["STCFN"+code];
    }
  }
}


class GameResources {
  HashMap<String, AudioBuffer> sampleMap = new HashMap<String, AudioBuffer>();
  HashMap<String, Image> wallTextures, flats, sprites;
  WAD.WadFile wadFile;
  
  GameResources(this.wadFile) {
  }
  
  void loadAll() {
    printToConsole("Loading graphics");
    loadGraphics();
    printToConsole("Loading sounds");
    loadSounds();
    renderers.prepare();
  }
  
  void loadGraphics() {
    wadFile.flats["_sky_"] = new WAD.Image.empty("_sky_",  64,  64);
    wallTextures = loadImagesIntoTextureAtlases(wadFile.wallTextures, renderers.addWallMap);
    flats = loadImagesIntoTextureAtlases(wadFile.flats, renderers.setFlatMap);
    sprites = loadImagesIntoTextureAtlases(wadFile.sprites, renderers.addSpriteMap);
    sprites.addAll(loadImagesIntoTextureAtlases(wadFile.images, renderers.addSpriteMap));
  }
  
  HashMap<String, Image> loadImagesIntoTextureAtlases(HashMap<String, WAD.Image> wadImages, Function onNewImageAtlas) {
    HashMap<String, Image> result = new HashMap<String, Image>();
    List<Image> toInsert = new List<Image>();
    wadImages.forEach((name, wadImage) {
      Image image = new Image.fromWadImage(wadImage);
      result[name] = image;
      toInsert.add(image);
    });
    toInsert.sort((i0, i1)=>(i1.width*i1.height)-(i0.width*i0.height));
    
    do {
      ImageAtlas imageAtlas = new ImageAtlas(TEXTURE_ATLAS_SIZE, TEXTURE_ATLAS_SIZE);
      for (int i=0; i<toInsert.length; i++) {
        if (imageAtlas.insert(toInsert[i])) {
          toInsert.removeAt(i--);
        }
      }
      imageAtlas.render();
      onNewImageAtlas(imageAtlas.texture);
    } while (toInsert.length>0);
    
    return result;
  }
  
  void loadSounds() {
    wadFile.samples.forEach((name, sample) {
      if (sample==null) {
        printToConsole("$name is not a sample!");
        AudioBuffer audioBuffer = audioContext.createBuffer(1, 1000, 11000);
        sampleMap[name] = audioBuffer;
      } else {
        AudioBuffer audioBuffer = audioContext.createBuffer(1,  sample.sampleCount, sample.rate);
        Float32List bufferData = audioBuffer.getChannelData(0);
        for (int i=0; i<sample.sampleCount; i++) {
          bufferData[i] = (sample.samples[i]/255.0)*2.0-1.0;
        }
        sampleMap[name] = audioBuffer;
      }
    });
  }
}