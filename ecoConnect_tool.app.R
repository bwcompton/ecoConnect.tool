# ecoConnect.tool.app.R - ecoConnect and IEI viewing and reporting tool
# Before initial deployment on shinyapps.io, need to restart R and:
#    library(remotes); install_github('https://github.com/elipousson/sfext.git'); install_github('bwcompton/leaflet.lagniappe')
# YOu'll need to get a Stadia Maps API  key from https://client.stadiamaps.com and save it in www/stadia_api.txt. Make sure 
# to .gitignore this file!

# B. Compton, 19 Apr



libraries <- c('shiny', 'bslib', 'bsicons', 'shinyjs', 'shinybusy', 'shinyWidgets', 'htmltools', 'markdown', 
               'leaflet', 'leaflet.extras', 'leaflet.lagniappe', 'terra', 'sf', 'future', 'promises', 'ggmap', 
               'ggplot2', 'httr')
source('loadlibs.R')
loadlibs(libraries)  # get loading times for libraries (for development)


library(shiny)
library(bslib)
library(bsicons)
library(shinyjs)
library(shinybusy)
library(shinyWidgets)
library(htmltools)
library(markdown)
library(leaflet)
library(leaflet.extras)
library(leaflet.lagniappe)
library(terra)
library(sf)
#library(lwgeom)           # apparently not using
library(future)
library(promises)
library(ggmap)
library(ggplot2)
#library(fs)               # apparently not using
#library(sfext)            # not using?
library(httr)              # for pinging GeoServer
###### library(geosphere)
###library(leaflet.esri)      # test, for PAD-US. It sucks





plan('multisession')


source('modalHelp.R')
source('get.WCS.data.R')
source('get.shapefile.R')
source('draw.poly.R')
source('call.make.report.R')
source('make.report.R')
source('make.report.maps.R')
source('layer.stats.R')
source('format.stats.R')
##source('addPADUS.R')     # dropped
source('addBoundaries.R')
source('addUserBasemap.R')



home <- c(-75, 42)            # center of NER (approx)
zoom <- 6 

layers <- data.frame(
   which = c('connect', 'connect', 'connect', 'connect', 'iei', 'iei', 'iei', 'iei'),
   workspaces = c('ecoConnect', 'ecoConnect', 'ecoConnect', 'ecoConnect', 'IEI', 'IEI', 'IEI', 'IEI'),
   server.names = c('Forest_fowet', 'Ridgetop', 'Nonfo_wet', 'LR_floodplain_forest', 'iei_regional', 'iei_state', 'iei_ecoregion', 'iei_huc6'),
   #   pretty.names = c('Forests', 'Ridgetops', 'Wetlands', 'Floodplain forests', 'IEI (region)', 'IEI (state)', 'IEI (ecoregion)', 'IEI (watershed)'),
   pretty.names = c('Forests', 'Ridgetops', 'Wetlands', 'Floodplain forests', 'Region', 'State', 'Ecoregion', 'Watershed'),
   radio.names = c('Forests', 'Ridgetops', 'Wetlands', 'Floodplain forests',
                   'Regional', 'State', 'Ecoregion', 'Watershed'))

full.layer.names <- paste0(layers$workspaces, ':', layers$server.names)       # we'll need these for addWMSTiles

WMSserver <- 'https://umassdsl.webgis1.com/geoserver/wms'                     # our WMS server for drawing maps
WCSserver <- 'https://umassdsl.webgis1.com/geoserver/'                        # our WCS server for downloading data



# tool tips
ecoConnectDisplayTooltip <- includeMarkdown('inst/tooltipEcoConnectDisplay.md')
projectAreaToolTip <- includeMarkdown('inst/tooltipProjectArea.md')
drawTooltip <- includeMarkdown('inst/tooltipDraw.md')
uploadTooltip <- includeMarkdown('inst/tooltipUpload.md')
restartTooltip <- includeMarkdown('inst/tooltipRestart.md')
getReportTooltip <- includeMarkdown('inst/tooltipGetReport.md')
generateReportTooltip <- includeMarkdown('inst/tooltipGenerateReport.md')
connectTooltip <- includeMarkdown('inst/tooltipConnect.md')
ieiTooltip <- includeMarkdown('inst/tooltipIei.md')
basemapTooltip <- includeMarkdown('inst/tooltipBasemap.md')
opacityTooltip <- includeMarkdown('inst/tooltipOpacity.md')
usermapTooltip <- includeMarkdown('inst/tooltipUsermap.md')


# help docs
aboutTool <- includeMarkdown('inst/aboutTool.md')
aboutecoConnect <- includeMarkdown('inst/aboutEcoConnect.md')
aboutIEI <- includeMarkdown('inst/aboutIEI.md')
aboutWhatsNew <- includeMarkdown('inst/aboutWhatsnew.md')



# User interface ---------------------
ui <- page_sidebar(
   theme = bs_theme(bootswatch = 'cerulean', version = 5),   # bslib version defense. Use version_default() to update
   useShinyjs(),
   extendShinyjs(script = 'fullscreen.js', functions = c('fullscreen', 'normalscreen', 'is_iOS')),
   tags$head(tags$link(rel = "stylesheet", type = "text/css", href = "fullscreen.css")),      # turn off dark background for fullscreen
   
   tags$head(tags$script(src = 'matomo.js')),               # add Matomo tracking JS
   tags$head(tags$script(src = 'matomo_heartbeat.js')),     # turn on heartbeat timer
   tags$script(src = 'matomo_events.js'),                   # track popups and help text
   
   title = 'ecoConnect tool (dev version)',
   
   sidebar = 
      sidebar(
         #add_busy_spinner(spin = 'fading-circle', position = 'top-left', onstart = TRUE, timeout = 0),   # for debugging
         add_busy_spinner(spin = 'fading-circle', position = 'top-left', onstart = FALSE, timeout = 500),
         use_busy_spinner(spin = 'fading-circle', position = 'top-left'),
         
         card(
            span(HTML('<h5 style="display: inline-block;">Project area report</h5>'),
                 tooltip(bs_icon('info-circle'), projectAreaToolTip)),
            
            span(span(actionButton('drawPolys', 'Draw'),
                      tooltip(bs_icon('info-circle'), drawTooltip),
                      HTML('&nbsp;'), HTML('or&nbsp;')),
                 
                 span(actionButton('uploadShapefile', 'Upload'),
                      tooltip(bs_icon('info-circle'), uploadTooltip))
            ),
            
            span(span(actionButton('getReport', 'Get report'),
                      tooltip(bs_icon('info-circle'), getReportTooltip)),
                 
                 span(actionButton('restart', 'Restart'),
                      tooltip(bs_icon('info-circle'), restartTooltip))
            )
         ),
         
         card(
            actionLink('aboutTool', label = 'About this site'),
            actionLink('aboutecoConnect', label = 'About ecoConnect'),
            actionLink('aboutIEI', label = 'About the Index of Ecological Integrity'),
            p(HTML('<a href="https://umassdsl.org/" target="_blank" rel="noopener noreferrer">UMass DSL home page</a>')),
            br(),
            span('Version 0.2.0', actionLink('whatsNew', label = 'What\'s new?')),
            br(),
            tags$img(height = 60, width = 199, src = 'UMass_DSL_logo_v2.png')
         ),
         width = 290
      ),
   
   layout_sidebar(
      sidebar = sidebar(
         position = 'right', 
         width = 280,
         
         card(
            radioButtons('iei.layer', label = span(HTML('<h5 style="display: inline-block;">IEI layers</h5>'), 
                                                   tooltip(bs_icon('info-circle'), ieiTooltip)), 
                         choiceNames = layers$radio.names[layers$which == 'iei'],
                         choiceValues = full.layer.names[layers$which == 'iei'],
                         selected = character(0))
         ),
         
         card( 
            radioButtons('connect.layer', label = span(HTML('<h5 style="display: inline-block;">ecoConnect layers</h5>'), 
                                                       tooltip(bs_icon('info-circle'), connectTooltip)), 
                         choiceNames = layers$radio.names[layers$which == 'connect'],
                         choiceValues = full.layer.names[layers$which == 'connect']),
            
            sliderTextInput('ecoConnectDisplay', span(HTML('<h5 style="display: inline-block;">ecoConnect display</h5>'), 
                                                      tooltip(bs_icon('info-circle'), ecoConnectDisplayTooltip)), 
                            choices = c('local', 'medium', 'regional'))
            
         ),
         
         card(
            
            sliderInput('opacity', span(HTML('<h5 style="display: inline-block;">Layer opacity</h5>'), 
                                        tooltip(bs_icon('info-circle'), opacityTooltip)), 
                        0, 100, post = '%', value = 60, ticks = FALSE),
            
            actionButton('no.layers', 'Turn off layers')
         ),
         
         card(
            radioButtons('show.basemap', span(HTML('<h5 style="display: inline-block;">Basemap</h5>'),
                                              tooltip(bs_icon('info-circle'), basemapTooltip)),
                         choiceNames = c('Simple map', 'Open Street Map', 'Topo map', 'Imagery'),
                         choiceValues = c('Stadia.StamenTonerLite', 'OpenStreetMap.Mapnik', 'USGS.USTopo', 'USGS.USImagery')),
            hr(),
            checkboxInput('show.boundaries', label = 'Show states and counties', value = FALSE),
            checkboxInput('show.usermap', label = 'Show user basemap', value = FALSE),                          # ...........................
            span(actionButton('upload.usermap', 'Upload user basemap'),
                 tooltip(bs_icon('info-circle'), usermapTooltip))
            
         ),
         
         card(
            materialSwitch(inputId = 'fullscreen', label = 'Full screen', value = FALSE, 
                           status = 'default')
         )
      ),
      
      leafletOutput('map')
   )
)



# Server -----------------------------
server <- function(input, output, session) {
   shinyjs::disable('restart')
   shinyjs::disable('getReport')
   shinyjs::disable('show.usermap')
   
   #bs_themer()                                 # uncomment to select a new theme
   #  print(getDefaultReactiveDomain())
   
   tryCatch({
      if(GET(WCSserver)$status_code != 200) stop()
   }, 
   error = function(e) {      # ping our GeoServer
      showModal(modalDialog(
         title = 'Error', 
         includeMarkdown('inst/errorGeoServer.md'),
         footer = modalButton('OK'),
         easyClose = TRUE
      ))
      shinyjs::disable('drawPolys')
      shinyjs::disable('uploadShapefile')
   })
   
   observeEvent(input$aboutTool, {
      modalHelp(aboutTool, 'About this site', size = 'l')})
   observeEvent(input$aboutecoConnect, {
      modalHelp(aboutecoConnect, 'About ecoConnect', size = 'l')})
   observeEvent(input$aboutIEI, {
      modalHelp(aboutIEI, 'About the Index of Ecological Integrity', size = 'l')})
   observeEvent(input$whatsNew, {
      modalHelp(aboutWhatsNew, 'What\'s new in this version?')})
   
   
   output$map <- renderLeaflet({                                                    # ----- Draw static parts of Leaflet map
      leaflet('map',
              options = leafletOptions(maxZoom = 16)) |>
         addScaleBar(position = 'bottomleft') |>
         osmGeocoder(position = 'bottomright', email = 'bcompton@umass.edu') |>
         setView(lng = home[1], lat = home[2], zoom = zoom)
   })
   
   observeEvent(input$fullscreen, 
                js$fullscreen(input$fullscreen), ignoreInit = TRUE)
   
   observeEvent(input$connect.layer, {
      session$userData$show.layer <- input$connect.layer
      updateRadioButtons(inputId ='iei.layer', selected = character(0))
      enable('ecoConnectDisplay')
      enable('opacity')
   })
   
   observeEvent(input$iei.layer, {
      session$userData$show.layer <- input$iei.layer
      updateRadioButtons(inputId ='connect.layer', selected = character(0))
      updateCheckboxInput(inputId = 'no.layers', value = 0)
      disable('ecoConnectDisplay')
      enable('opacity')
   })
   
   observeEvent(input$no.layers, {
      session$userData$show.layer <- 'none'
      updateRadioButtons(inputId ='iei.layer', selected = character(0))
      updateRadioButtons(inputId ='connect.layer', selected = character(0))
      updateCheckboxInput(inputId = 'no.layers', value = 0)
      disable('ecoConnectDisplay')
      disable('opacity')
   })
   
   observeEvent(list(input$connect.layer, input$iei.layer, input$show.basemap,   # ----- Draw dynamic parts of Leaflet map           ........................
                     input$opacity, input$autoscale, input$ecoConnectDisplay, input$show.boundaries,
                     input$show.usermap), {
                        if(length(session$userData$show.layer) != 0 && session$userData$show.layer == 'none')
                           leafletProxy('map') |>
                           addProviderTiles(provider = input$show.basemap, layerId = 'basemap') |>
                           removeTiles(layerId = 'dsl.layers') |>
                           addUserBasemap(input$show.usermap, session$userData$userPoly) |>
                           addBoundaries(input$show.boundaries)
                        else {
                           if(sub(':.*', '', session$userData$show.layer) == 'ecoConnect')                 # if ecoConnect, use scaled style
                              style <- paste0(sub('.*:', '', session$userData$show.layer), 
                                              match(input$ecoConnectDisplay, c('local', 'medium', 'regional')) / 2 + 0.5)
                           else                                                                            # else, use default style for IEI
                              style <- ''
                           
                           leafletProxy('map') |>
                              addProviderTiles(provider = input$show.basemap, layerId = 'basemap') |>
                              addWMSTiles(WMSserver, layerId = 'dsl.layers', layers = session$userData$show.layer,
                                          options = WMSTileOptions(opacity = input$opacity / 100, styles = style)) |>
                              addUserBasemap(input$show.usermap, session$userData$userPoly) |>
                              addBoundaries(input$show.boundaries)
                           
                           
                        }
                     })
   
   observeEvent(input$drawPolys, {                    # ----- Draw button
      shinyjs::disable('drawPolys')
      shinyjs::disable('uploadShapefile')
      shinyjs::enable('restart')
      
      session$userData$drawn <- TRUE
      proxy <- leafletProxy('map')
      addDrawToolbar(proxy, polygonOptions = drawPolygonOptions(shapeOptions = drawShapeOptions(color = 'purple', weight = 4, fillOpacity = 0)), 
                     polylineOptions = FALSE, circleOptions = FALSE, rectangleOptions = FALSE, markerOptions = FALSE, 
                     circleMarkerOptions = FALSE, editOptions = editToolbarOptions()) 
   })
   
   observeEvent(input$map_draw_all_features, {        # when the first poly is finished, get report becomes available
      if(!is.null(input$map_draw_all_features))
         shinyjs::enable('getReport')
   })
   
   observeEvent(input$uploadShapefile, {              # ----- Upload button
      # do modal dialog to get shapefile
      showModal(modalDialog(
         title = 'Select shapefile to upload',
         fileInput('shapefile', '', accept = c('.shp', '.shx', '.prj', '.zip'), multiple = TRUE, 
                   placeholder = 'must include .shp, .shx, and .prj', width = '100%'),
         footer = tagList(
            modalButton('OK'),
            actionButton('restart', 'Cancel'))
      ))
      shinyjs::disable('getReport')
   })
   
   observeEvent(input$shapefile, {                    # --- Have uploaded shapefile
      tryCatch({
         session$userData$poly <- get.shapefile(input$shapefile)
         draw.poly(session$userData$poly)
         session$userData$drawn <- FALSE
         shinyjs::disable('drawPolys')
         shinyjs::disable('uploadShapefile')
         shinyjs::enable('getReport')
         shinyjs::enable('restart')
      },
      error = function(e) {
         showModal(modalDialog(
            title = 'Error',
            includeMarkdown('inst/errorShapefile.md'),
            footer = modalButton('OK'),
            easyClose = TRUE
         ))
         shinyjs::enable('drawPolys')                 # bad shapefile: do a restart
         shinyjs::enable('uploadShapefile')
         shinyjs::disable('restart')
         shinyjs::disable('getReport')
      })
   })
   
   
   observeEvent(input$restart, {                      # ----- Restart button
      shinyjs::enable('drawPolys')
      shinyjs::enable('uploadShapefile')
      shinyjs::disable('restart')
      shinyjs::disable('getReport')
      removeModal()                                   # when triggered by cancel button in upload
      
      leafletProxy('map') |>
         removeDrawToolbar(clearFeatures = TRUE) |>
         clearGroup(group = 'targetArea')                                                  # <<<<<<<<<<<<<<<<<<< I think this will also clear user basemap!
   })
   
   
   
   observeEvent(input$upload.usermap, {              # ----- Upload map button for user basemap                ..................................................
      # do modal dialog to get shapefile
      showModal(modalDialog(
         title = 'Select shapefile to upload',
         fileInput('user.shapefile', '', accept = c('.shp', '.shx', '.prj', '.zip'), multiple = TRUE, 
                   placeholder = 'must include .shp, .shx, and .prj', width = '100%'),
         footer = tagList(
            modalButton('Done'))
      ))
   })
   
   observeEvent(input$user.shapefile, {               # --- Have uploaded shapefile for user basemap                ..................................................
      tryCatch({
         session$userData$userPoly <- get.shapefile(input$user.shapefile, merge = FALSE)
         leafletProxy('map') |>
            addUserBasemap(FALSE) |>                   # clear old shapefile
            addUserBasemap(TRUE, session$userData$userPoly)
         shinyjs::enable('show.usermap')
         updateCheckboxInput('show.usermap', value = TRUE, session = getDefaultReactiveDomain())
      }, 
      error = function(e) {
         showModal(modalDialog(
            title = 'Error',
            includeMarkdown('inst/errorShapefile.md'),
            footer = modalButton('OK'),
            easyClose = TRUE
         ))
      })
   })
   
   
   
   observeEvent(input$getReport, {                    # ----- Get report button
      output$time <- renderText({
         paste('Wait time ', round(session$userData$time, 2), ' sec', sep = '')
      })
      
      
      if(session$userData$drawn)                      #     If drawn polygon,
         session$userData$poly <- geojsonio::geojson_sf(jsonlite::toJSON(input$map_draw_all_features, auto_unbox = TRUE))  #    drawn poly as sf
      
      session$userData$saved <- list(input$proj.name, input$proj.info)
      session$userData$poly <- st_make_valid(session$userData$poly)    # attempt to fix bad shapefiles
      session$userData$poly.proj <- st_transform(session$userData$poly, 'epsg:3857', type = 'proj') # project to match downloaded rasters
      session$userData$bbox <- as.list(st_bbox(session$userData$poly.proj))
      
      bbarea <- (session$userData$bbox$xmax - session$userData$bbox$xmin) * (session$userData$bbox$ymax - session$userData$bbox$ymin) * 247.105e-6
      if(bbarea > 1e6) {
         showModal(modalDialog(
            title = 'Error', 
            includeMarkdown('inst/errorToobig.md'),
            footer = modalButton('OK'),
            easyClose = TRUE
         ))
         return()
      }
      
      showModal(modalDialog(                          # --- Modal input to get project name and description
         textInput('proj.name', 'Project name', value = input$proj.name, width = '100%',
                   placeholder = 'Project name for report'),
         textAreaInput('proj.info', 'Project description', value = input$proj.info, 
                       width = '100%', rows = 6, placeholder = 'Optional project description'),
         footer = tagList(
            show_spinner(),
            span(disabled(downloadButton('do.report', 'Generate report')), tooltip(bs_icon('info-circle'), generateReportTooltip)),
            actionButton('cancel.report', 'Cancel')
         )
      ))
      
      
      # -- Download data while user is typing project info
      
      xxpoly <<- session$userData$poly
      xxpoly.proj <<- session$userData$poly.proj
      #  st_write(session$userData$poly, 'C:/GIS/GIS/sample_parcels/name.shp')  # save drawn poly as shapefile
      
      # cat('*** PID ', Sys.getpid(), ' asking to download data in the future...\n', sep = '')
      t <- Sys.time()
      downloading <- showNotification('Downloading data...', duration = NULL, closeButton = FALSE)
      
      
      session$userData$the.promise <- future_promise({
         #cat('*** PID ', Sys.getpid(), ' is working in the future...\n', sep = '')
         get.WCS.data(WCSserver, layers$workspaces, layers$server.names, session$userData$bbox)    # ----- Download data in the future  
      }) 
      then(session$userData$the.promise, onFulfilled = function(x) {
         #   cat('*** The promise has been fulfilled!\n')
         enable('do.report')
         hide_spinner()
         removeNotification(downloading)
      }) 
      session$userData$time <- Sys.time() - t
      NULL
   })
   
   
   observeEvent(input$cancel.report, {                            # --- Cancel button from report dialog. Go back to previous values
      removeModal()
      updateTextInput(inputId = 'proj.name', value = session$userData$saved[[1]])
      updateTextInput(inputId = 'proj.info', value = session$userData$saved[[2]])
   })
   
   
   # --- Generate report button from report dialog
   output$do.report <- downloadHandler(
      file = 'report.pdf',
      content = function(f) {
         removeModal()   
         session$userData$the.promise %...>% 
            call.make.report(., f, layers, session$userData$poly, session$userData$poly.proj, 
                             input$proj.name, input$proj.info, session = getDefaultReactiveDomain())       
      })
}

shinyApp(ui, server)


