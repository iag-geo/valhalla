# edit and cut & paste this script into the QGIS Python window

# ignore_layers = ["Google Satellite Hybrid", "CartoDb Dark Matter", "CartoDb Positron", ]
layer_prefixes = ["vw_valhalla_", "valhalla_", "temp_"]
filter_text = "trip_id = '9113834E-158F-4328-B5A4-59B3A5D4BEFC' and search_radius = 15 and gps_accuracy = 7.5"

extent = QgsRectangle()
extent.setMinimal()
layers = iface.mapCanvas().layers()

# filter matching layers
for layer in layers:
    # if layer.name() not in ignore_layers:
    if layer.name().startswith(layer_prefixes[0]) or layer.name().startswith(layer_prefixes[1]):
        layer.setSubsetString(filter_text)
        extent.combineExtentWith( layer.extent() )

# set map extents to filtered datasets
sourceCrs = QgsCoordinateReferenceSystem("EPSG:4283")
destCrs = QgsCoordinateReferenceSystem("EPSG:900913")
tr = QgsCoordinateTransform(sourceCrs, destCrs, QgsProject.instance())
web_merc_extent = tr.transformBoundingBox(extent)
web_merc_extent.scale(1.3)
iface.mapCanvas().setExtent( web_merc_extent )
iface.mapCanvas().refresh()
