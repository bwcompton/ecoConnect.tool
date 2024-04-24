'get.WCS.data' <- function(layer.info, bbox) {
   
   # get.WCS.data
   # Download several layers on WCS server
   # Arguments:
   #     layer.info     list of layer info from get.WCS.info
   #     bbox            bounding bbox
   # Result:
   #     list of layer terra objects
   # B. Compton, 23 Apr 2024
   
   
   
   layers <- names(layer.info)
   z <- list()
   
   for(i in 1:length(layers)) 
       z[[layers[i]]] <- layer.info[[i]]$getCoverage(bbox = OWSUtils$toBBOX(bbox$xmin, bbox$xmax, bbox$ymin, bbox$ymax))
    z  
}