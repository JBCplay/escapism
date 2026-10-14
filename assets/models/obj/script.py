import trimesh

# Carrega o OBJ
mesh = trimesh.load('knightStanding.obj')

# Exporta direto para GLB
mesh.export('knightStandingColored.glb')