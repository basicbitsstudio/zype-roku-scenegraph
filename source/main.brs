Library "Roku_Ads.brs"

' ********** Copyright 2016 Zype Inc.  All Rights Reserved. **********
Function Main (args as Dynamic) as Void
    if (args.ContentID <> invalid) and (args.MediaType <> invalid)
        if (args <> invalid)
            contentID   = args.contentID
            mediaType   = LCase(args.mediatype)
            SetHomeScene(contentID, mediaType)
        end if
    else
        SetHomeScene()
    end if
End Function

Sub SetHomeScene(contentID = invalid, mediaType = invalid)
    screen = CreateObject("roSGScreen")

    m.app = GetAppConfigs()

    m.global = screen.getGlobalNode()

    m.current_user = CurrentUser()

    if RegReadAccessToken() <> invalid
      if m.current_user.isLinked() then GetAndSaveNewToken("device_linking") else GetAndSaveNewToken("login")
    end if

    SetTheme()
    SetFeatures()
    SetMonetizationSettings()
    SetVersion()
    SetTextLabels()

    m.favorites_storage_service = FavoritesStorageService()
    m.favorites_management_service = FavoritesManagementService()

    m.scene = screen.CreateScene("HomeScene")
    m.port = CreateObject("roMessagePort")
    screen.SetMessagePort(m.port)
    screen.Show()

    m.TestInfoScreen = m.scene.findNode("TestInfoScreen")

    m.store = CreateObject("roChannelStore")
    ' m.store.FakeServer(true)
    m.store.SetMessagePort(m.port)
    m.purchasedItems = []
    m.productsCatalog = []
    m.playlistRows = []
    m.videosList = []

    ' Set up services
    m.roku_store_service = RokuStoreService(m.store, m.port)
    m.auth_state_service = AuthStateService()
    m.bifrost_service = BiFrostService()
    m.raf_service = RafService()

    m.native_email_storage =  NativeEmailStorageService()

    SetGlobalAuthObject()

    m.AKaMAAnalyticsPlugin = AkaMA_plugin()
    m.akamai_service = AkamaiService()


    m.LoadingScreen = m.scene.findNode("LoadingScreen")

    m.loadingIndicator = m.scene.findNode("loadingIndicator")
    m.loadingIndicator1 = m.scene.findNode("loadingIndicator1")


    m.playlistsRowItemSizes = []
    m.playlistRowsSpacings = []


    m.contentID = contentID
    ' Start loader if deep linked
    if m.contentID <> invalid
      m.loadingIndicator.control = "stop"
      StartLoader()
    end if

    m.detailsScreen = m.scene.findNode("DetailsScreen")

    'm.scene.gridContent = ParseContent(GetContent()) ' Uses featured categories (depreciated)
    m.gridContent = ParseContent(GetPlaylistsAsRows(m.app.featured_playlist_id))

    m.gridScreen = m.scene.findNode("GridScreen")
    rowlist = m.gridScreen.findNode("RowList")
    rowlist.rowItemSize = m.playlistsRowItemSizes
    rowlist.rowSpacings = m.playlistRowsSpacings

    m.scene.gridContent = m.gridContent

    if m.contentID = invalid
      ' Keep loader spinning. App not done loading yet
      m.gridScreen.setFocus(false)
      m.loadingIndicator.control = "start"
    end if

    m.Menu = m.scene.findNode("Menu")
    m.Menu.isDeviceLinkingEnabled = m.app.device_linking

    print "[Main] Init"

    m.infoScreen = m.scene.findNode("InfoScreen")
    m.infoScreenText = m.infoScreen.findNode("Info")
    m.infoScreenText.text = m.app.about_page

    m.search = m.scene.findNode("Search")
    m.searchDetailsScreen = m.search.findNode("SearchDetailsScreen")
    m.searchDetailsScreen.observeField("itemSelected", m.port)

    m.favorites = m.scene.findNode("Favorites")
    m.favorites.observeField("visible", m.port)

    m.favoritesDetailsScreen = m.favorites.findNode("FavoritesDetailsScreen")
    m.favoritesDetailsScreen.observeField("itemSelected", m.port)

    m.detailsScreen.observeField("itemSelected", m.port)
    m.detailsScreen.productsCatalog = m.productsCatalog
    m.detailsScreen.observeField("triggerPlay", m.port)
    m.detailsScreen.dataArray = m.playlistRows

    m.scene.videoliststack = [m.videosList]
    m.detailsScreen.videosTree = m.scene.videoliststack.peek()
    m.detailsScreen.autoplay = m.app.autoplay

    m.AuthSelection = m.scene.findNode("AuthSelection")
    m.AuthSelection.plans = m.roku_store_service.GetNativeSubscriptionPlans()
    m.AuthSelection.observeField("itemSelected", m.port)
    m.AuthSelection.observeField("planSelected", m.port)

    m.MyLibrary = m.scene.findNode("MyLibrary")
    m.MyLibrary.observeField("visible", m.port)
    m.MyLibrary.observeField("paginatorSelected", m.port)

    m.MyLibraryDetailsScreen = m.MyLibrary.findNode("MyLibraryDetailsScreen")
    m.MyLibraryDetailsScreen.observeField("itemSelected", m.port)

    m.my_library_content = []

    m.UniversalAuthSelection = m.scene.findNode("UniversalAuthSelection")
    m.UniversalAuthSelection.observeField("itemSelected", m.port)

    m.SignInScreen = m.scene.findNode("SignInScreen")
    m.SignInScreen.header = m.global.labels.sign_in_screen_header
    m.SignInScreen.helperMessage = m.global.labels.sign_in_helper_message
    m.SignInScreen.submitButtonText = m.global.labels.sign_in_submit_button
    m.SignInScreen.observeField("itemSelected", m.port)

    m.SignUpScreen = m.scene.findNode("SignUpScreen")
    m.SignUpScreen.header = m.global.labels.sign_up_screen_header
    m.SignUpScreen.helperMessage = m.global.labels.sign_up_helper_message
    m.SignUpScreen.submitButtonText = m.global.labels.sign_up_submit_button
    m.SignUpScreen.observeField("itemSelected", m.port)

    m.AccountScreen = m.scene.findNode("AccountScreen")
    m.AccountScreen.observeField("itemSelected", m.port)

    m.scene.observeField("SearchString", m.port)

    m.scene.observeField("playlistItemSelected", m.port)
    m.scene.observeField("TriggerDeviceUnlink", m.port)

    user_info = m.current_user.getInfo()

    m.deviceLinking = m.scene.findNode("DeviceLinking")
    m.deviceLinking.DeviceLinkingURL = m.app.device_link_url
    m.deviceLinking.isDeviceLinked = user_info.linked
    m.deviceLinking.observeField("show", m.port)
    m.deviceLinking.observeField("itemSelected", m.port)

    LoadLimitStream() ' Load LimitStream Object

    fav_ids = GetFavoritesIDs()
    m.favorites_management_service.setFavoriteIds(fav_ids)

    startDate = CreateObject("roDateTime")

    ' Deep Linking
    if (m.contentID <> invalid)
        if mediaType <> "season" and mediaType <> "series"
          ' Get video object and create VideoNode
          linkedVideo = GetVideo(m.contentID)

          ' If m.contentID is for active video
          if linkedVideo.DoesExist("_id") and linkedVideo.active = true
            linkedVideoObject =  CreateVideoObject(linkedVideo)
            linkedVideoNode = createObject("roSGNode", "VideoNode")

            for each key in linkedVideoObject
              linkedVideoNode[key] = linkedVideoObject[key]
            end for

            ' Set focused content to linkedVideoNode
            m.gridScreen.focusedContent = linkedVideoNode
            m.gridScreen.visible = "false"
            m.detailsScreen.content = m.gridScreen.focusedContent
            m.detailsScreen.setFocus(true)
            m.detailsScreen.visible = "true"

            ' Trigger listener to push detailsScreen into HomeScene screenStack
            m.scene.DeepLinkedID = m.contentID

            is_subscribed = (m.global.auth.nativeSubCount > 0 or m.global.auth.universalSubCount)

            ' Start playing video if logged in or no monetization
            if is_subscribed = true or (linkedVideo.subscription_required = false and linkedVideo.purchase_required = false)
                m.akamai_service.setPlayStartedOnce(true)
                playRegularVideo(m.detailsScreen)
            end if
          end if

        else if mediaType = "season" or mediaType = "series"
          deep_linked_playlist = GetPlaylists({ id: m.contentID })
          valid_playlist = (deep_linked_playlist.count() > 0 and deep_linked_playlist[0].active)

          if valid_playlist
            transitionToNestedPlaylist(m.contentID)
          end if
        end if


      ' Close loading screen if still visible
      if m.LoadingScreen.visible = true
        EndLoader()

        ' Trigger grid screen refocus if visible
        if m.gridScreen.visible = true
          m.scene.gridContent = m.scene.gridContent
        end if
      end if
    end if

    if m.contentID = invalid
      ' Stop loader and refocus
      m.gridScreen.setFocus(true)
      m.loadingIndicator.control = "stop"
    end if

    print "App done loading"

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)

        print "msg.getField(): "; msg.getField()
        print "msg.getData(): "; msg.getData()
        print "msg.getNode(): "; msg.getNode()

        if msgType = "roSGNodeEvent"
            if m.app.autoplay = true AND msg.getField() = "triggerPlay" AND msg.getData() = true then
              RemakeVideoPlayer(m.detailsScreen)
              RemoveVideoIdForResumeFromReg(m.detailsScreen.content.id)
              m.akamai_service.setPlayStartedOnce(true)
              playRegularVideo(m.detailsScreen)
            else if msg.getField() = "playlistItemSelected" and msg.GetData() = true and m.gridScreen.focusedContent.contentType = 2 then
                m.loadingIndicator.control = "start"
                m.gridScreen.playlistItemSelected = false
                content = m.gridScreen.focusedContent

                ' Get Playlist object from the platform
                playlistObject = GetPlaylists({ id: content.id })
                playlistThumbnailLayout = playlistObject[0].thumbnail_layout
                m.gridScreen.content = ParseContent(GetPlaylistsAsRows(content.id, playlistThumbnailLayout))
                m.gridContent = m.gridScreen.content

                rowlist = m.gridScreen.findNode("RowList")
                rowlist.rowItemSize = m.playlistsRowItemSizes
                rowlist.rowSpacings = m.playlistRowsSpacings

                rowlist.jumpToRowItem = [0,0]

                m.scene.gridContent = m.gridContent

                current_video_list_stack = m.scene.videoliststack
                current_video_list_stack.push(m.videosList)
                m.scene.videoliststack = current_video_list_stack

                m.detailsScreen.videosTree = m.scene.videoliststack.peek()

                m.loadingIndicator.control = "stop"
            else if msg.getNode() = "Favorites" and msg.getField() = "visible" and msg.getData() = true
                m.loadingIndicator.control = "start"


                favorites_content = GetFavoritesContent()
                m.scene.favoritesContent = ParseContent(favorites_content)

                if favorites_content.count() = 0 then m.Favorites.VideoTitleText = m.global.labels.no_favorites_message

                m.loadingIndicator.control = "stop"

            else if msg.getNode() = "MyLibrary" and msg.getField() = "visible" and msg.getData() = true
                sign_in_button = m.MyLibrary.findNode("SignInButton")
                my_library_gridscreen = m.MyLibrary.findNode("Grid")
                my_library_gridscreen.setFocus(false)

                if m.global.auth.isLoggedIn
                    sign_in_button.visible = false
                    m.loadingIndicator.control = "start"
                else
                    sign_in_button.visible = true
                    sign_in_button.setFocus(true)
                end if

                my_library_count = ContentHelpers().CountTwoDimContentNodeAtIndex(m.scene.myLibraryContent, 0)

                if m.global.auth.isLoggedIn
                    sign_in_button.setFocus(false)

                    ' MyLibrary was set
                    if my_library_count > 0
                        my_library_gridscreen.setFocus(true)

                    ' get MyLibrary first time
                    else
                        my_library = GetMyLibraryContent(true)

                        m.my_library_content = ArrayHelpers().RemoveDuplicatesBy(my_library[0].contentList, "id")

                        my_library_content = {
                            contentList: m.my_library_content,
                            title: my_library[0].title
                        }

                        if m.my_library_content.count() > 0
                            ' Push paginator to get next page
                            my_library_content.contentList.push(Paginator(2))

                            m.scene.myLibraryContent = ParseContent([my_library_content])
                            my_library_gridscreen.setFocus(true)
                        else
                            m.scene.myLibraryContent = ParseContent([my_library_content])
                            my_library_gridscreen.setFocus(false)
                        end if
                    end if

                else
                    m.scene.myLibraryContent = ParseContent(GetMyLibraryContent(false))
                    my_library_gridscreen.setFocus(false)
                    sign_in_button.setFocus(true)
                end if

                m.loadingIndicator.control = "stop"
                m.MyLibrary.setFocus(true)

            else if msg.getField() = "paginatorSelected" and msg.getData() = true and msg.getNode() = "MyLibrary"
                my_library_focused = m.MyLibrary.focusedContent

                my_library_next_page = GetMyLibraryContent(true, my_library_focused.nextPage)
                my_library_next_page_count = my_library_next_page[0].contentList.count()

                ' Remove Paginator
                m.my_library_content.pop()

                m.my_library_content.append(my_library_next_page[0].contentList)
                m.my_library_content = ArrayHelpers().RemoveDuplicatesBy(m.my_library_content, "id")

                new_my_library = {
                    title: m.scene.myLibraryContent.GetChild(0).title,
                    contentList: m.my_library_content
                }

                ' add paginator only if next page is next page content is not empty
                if my_library_next_page_count > 0 then new_my_library.contentList.push(Paginator(my_library_focused.nextPage + 1))


                m.scene.myLibraryContent = ParseContent([new_my_library])
                m.MyLibrary.setFocus(true)
            else if msg.getField() = "SearchString"
                m.loadingIndicator.control = "start"
                SearchQuery(m.scene.SearchString)
                m.loadingIndicator.control = "stop"
            else if (msg.getNode() = "FavoritesDetailsScreen" or msg.getNode() = "SearchDetailsScreen" or msg.getNode() = "MyLibraryDetailsScreen" or msg.getNode() = "DetailsScreen" or msg.getNode() = "AuthSelection" or msg.getNode() = "UniversalAuthSelection" or msg.getNode() = "SignInScreen" or msg.getNode() = "SignUpScreen" or msg.getNode() = "AccountScreen") and msg.getField() = "itemSelected" then

                ' access component node content
                if msg.getNode() = "FavoritesDetailsScreen"
                    lclScreen = m.favoritesDetailsScreen
                else if msg.getNode() = "SearchDetailsScreen"
                    lclScreen = m.searchDetailsScreen
                else if msg.getNode() = "MyLibraryDetailsScreen"
                    lclScreen = m.MyLibraryDetailsScreen
                else if msg.getNode() = "DetailsScreen"
                    lclScreen = m.detailsScreen
                else if msg.getNode() = "AuthSelection"
                    lclScreen = m.AuthSelection
                else if msg.getNode() = "UniversalAuthSelection"
                    lclScreen = m.UniversalAuthSelection
                else if msg.getNode() = "SignInScreen"
                    lclScreen = m.SignInScreen
                else if msg.getNode() = "SignUpScreen"
                    lclScreen = m.SignUpScreen
                else if msg.getNode() = "AccountScreen"
                    lclScreen = m.AccountScreen
                end if

                index = msg.getData()

                handleButtonEvents(index, lclscreen)

            else if msg.getNode() = "AuthSelection" and msg.getField() = "planSelected" then
              app_info = CreateObject("roAppInfo")

              plan = m.AuthSelection.currentPlanSelected
              already_purchased = m.roku_store_service.alreadyPurchased(plan.code)

              already_purchased_message = "It appears you have already purchased this plan before. If you cancelled your subscription, please renew your subscription on the Roku website. " + chr(10) + chr(10) + "Then you can sign in with your " + app_info.getTitle() + " account."

              if already_purchased
                CreateDialog(m.scene, "Already purchased", already_purchased_message, ["Close"])
              else
                if m.global.auth.isLoggedIn or m.global.native_to_universal_subscription = false then handleNativeToUniversal() else m.scene.transitionTo = "SignUpScreen"
              end if
            else if msg.getField() = "state"
                state = msg.getData()
                m.akamai_service.handleVideoEvents(state, m.AKaMAAnalyticsPlugin.pluginInstance, m.AKaMAAnalyticsPlugin.sessionTimer, m.AKaMAAnalyticsPlugin.lastHeadPosition)

                if m.scene.focusedChild.id = "DetailsScreen"
                  ' autoplay
                  next_video = m.detailsScreen.videosTree[m.detailsScreen.PlaylistRowIndex][m.detailsScreen.CurrentVideoIndex]
                  if state = "finished" and m.detailsScreen.autoplay = true and m.detailsScreen.canWatchVideo = true and next_video <> invalid
                      m.detailsScreen.triggerPlay = true
                  end if
                end if
            else if msg.getField() = "position"
                m.AKaMAAnalyticsPlugin.lastHeadPosition = m.videoPlayer.position
                print m.videoPlayer.position
                if(m.videoPlayer.position >= 30 and m.videoPlayer.content.onAir = false)
                    AddVideoIdForResumeToReg(m.videoPlayer.content.id,m.videoPlayer.position.ToStr())
                    AddVideoIdTimeSaveForResumeToReg(m.videoPlayer.content.id,startDate.asSeconds().ToStr())
                end if

	            ' If midroll ads exist, watch for midroll ads
	            if m.midroll_ads <> invalid and m.midroll_ads.count() > 0
                    handleMidrollAd()
	            end if ' end of midroll ad if statement
            else if msg.getNode() = "DeviceLinking" and msg.getField() = "show" and msg.GetData() = true then
                m.scene.transitionTo = "DeviceLinking"
                goIntoDeviceLinkingFlow()
            else if msg.getNode() = "DeviceLinking" AND msg.getField() = "itemSelected" then
                print "[Main] Device Linking -> Item Selected"

                sleep(500)

                m.scene.dialog = invalid
                dialog = createObject("roSGNode", "Dialog")
                dialog.title = "Device Unlink Confirmation"
                dialog.message = "Are you sure you want to unlink your device? You will need to link your device again in order to access premium content."
                dialog.optionsDialog = true
                dialog.buttons = ["Yes", "No"]
                m.scene.dialog = dialog

            else if msg.getField() = "TriggerDeviceUnlink" AND msg.GetData() = true then
                isDeviceLinked = IsLinked({"linked_device_id": GetUdidFromReg(), "type": "roku"})
                res = UnlinkDevice(isDeviceLinked.consumer_id, isDeviceLinked.pin, {})

                if res <> invalid
                  m.scene.TriggerDeviceUnlink = false
                  m.auth_state_service.updateAuthWithUserInfo(m.current_user.getInfo())

                  m.scene.gridContent = m.gridContent

                  m.deviceLinking.isDeviceLinked = true
                  m.deviceLinking.setFocus(true)

                  ' Clear favorites
                  m.favorites_storage_service.ClearFavorites()
                  m.favorites_management_service.SetFavoriteIds({})
                end if
            end if ' end of field checking

        end if ' end of msgType = "roSGNodeEvent"
    end while

    print "You are exiting the app"

    if screen <> invalid then
        screen.Close()
        screen = invalid
    end if
End Sub

function goIntoDeviceLinkingFlow() as void
  pin = m.DeviceLinking.findNode("Pin")
  user_info = m.current_user.getInfo()

  if user_info.linked then pin.text = "You are linked" else pin.text = GetPin(GetUdidFromReg())

  website = m.DeviceLinking.findNode("LinkText2")
  website.text = m.app.device_link_url

  while true
      if m.deviceLinking.show = false
          exit while
      else
          print "refreshing PIN"
          pin_status = PinStatus({"linked_device_id": GetUdidFromReg()})

          if pin_status.linked then
              pin.text = "The device is linked"

              ' get and store access token locally
              GetAccessTokenWithPin(GetApiConfigs().client_id, GetApiConfigs().client_secret, GetUdidFromReg(), GetPin(GetUdidFromReg()))

              user_info = m.current_user.getInfo()
              m.auth_state_service.updateAuthWithUserInfo(user_info)

              m.deviceLinking.isDeviceLinked = true
              m.deviceLinking.setUnlinkFocus = true

              m.scene.gridContent = m.gridContent

              m.scene.goBackToNonAuth = true

              ' Reset details screen buttons
              m.detailsScreen.content = m.detailsScreen.content

              sleep(500)
              CreateDialog(m.scene, "Success", "Your device is linked", ["Continue"])
              exit while
          end if
      end if

      sleep(5000)
  end while
end function

function transitionToNestedPlaylist(id) as void
  m.scene.callFunc("AddCurrentPositionToTracker", invalid)
  m.scene.callFunc("PushContentIntoContentStack", m.gridScreen.content)
  m.scene.callFunc("PushScreenIntoScreenStack", m.gridScreen)

  m.gridScreen.playlistItemSelected = false

  m.gridScreen.content = ParseContent(GetPlaylistsAsRows(id))

  rowList = m.gridScreen.findNode("RowList")
  rowlist.jumpToRowItem = [0,0]

  current_video_list_stack = m.scene.videoliststack
  current_video_list_stack.push(m.videosList)
  m.scene.videoliststack = current_video_list_stack

  m.detailsScreen.videosTree = m.scene.videoliststack.peek()
end function

' Play button should only appear in the following scenarios:
'     1- No subscription required for video
'     2- NSVOD only and user has already purchased a native subscription
'     3- Both NSVOD and USVOD. User either purchased a native subscription or is linked
sub playRegularVideo(screen as Object)
    print "PLAY REGULAR VIDEO"
    StartLoader()
    di = CreateObject("roDeviceInfo")
    consumer = m.current_user.getInfo()

    if consumer._id <> invalid and consumer._id <> ""
        oauth = m.current_user.getOAuth()

        if IsEntitled(screen.content.id, {access_token: oauth.access_token})
          auth = {"access_token": oauth.access_token, "uuid": di.GetDeviceUniqueId()}
        else
          auth = {"app_key": GetApiConfigs().app_key, "uuid": di.GetDeviceUniqueId()}
        end if
    else
        auth = {"app_key": GetApiConfigs().app_key, "uuid": di.GetDeviceUniqueId()}
    end if

    playVideo(screen, auth, m.app.avod)
end sub

sub playVideo(screen as Object, auth As Object, adsEnabled = false)
    playerInfo = GetPlayerInfo(screen.content.id, auth)

    if(screen.content.onAir <> true AND playerInfo.analytics.beacon <> invalid AND playerInfo.analytics.beacon <> "")
        print "PlayerInfo.analytics: "; playerInfo.analytics

		if auth.access_token <> invalid then token_info = RetrieveTokenStatus({ access_token: auth.access_token }) else token_info = invalid
        if token_info <> invalid then consumer_id = token_info.resource_owner_id else consumer_id = ""

        cd = {
			siteId: playerInfo.analytics.siteid,
			videoId: playerInfo.analytics.videoid,
			title: screen.content.title,
			deviceType: playerInfo.analytics.device,
			playerId: playerInfo.analytics.playerId,
			contentLength: screen.content.length,
			consumerId: consumer_id
		}
        print "Custom Dimensions: "; cd
        m.AKaMAAnalyticsPlugin.pluginMain({configXML: playerInfo.analytics.beacon, customDimensions:cd})
    end if

    screen.content.stream = playerInfo.stream
    screen.content.streamFormat = playerInfo.streamFormat
    screen.content.url = playerInfo.url

    video_service = VideoService()

    ' If video source is not available
    if(playerInfo.statusCode <> 200 or screen.content.streamFormat = "(null)")
      CloseVideoPlayer()
      CreateVideoUnavailableDialog(playerInfo.errorMessage)
    else
		PrepareVideoPlayerWithSubtitles(screen, playerInfo.subtitles.count() > 0, playerInfo)
		playContent = true

        m.VideoPlayer = screen.VideoPlayer
        m.VideoPlayer.observeField("position", m.port)

        if(screen.content.onAir <> true)
            m.VideoPlayer.observeField("state", m.port)
        end if

        m.videoPlayer.content = screen.content

		if(adsEnabled)
      is_subscribed = (m.global.auth.nativeSubCount > 0 or m.global.auth.universalSubCount > 0)
			no_ads = (m.global.swaf and is_subscribed)
			ads = video_service.PrepareAds(playerInfo, no_ads)

			if screen.content.onAir = true then m.midroll_ads = [] else m.midroll_ads = ads.midroll

			m.loadingIndicator.control = "stop"

			' preroll ad
			if ads.preroll <> invalid
			  playContent = m.raf_service.playAds(playerInfo.video, ads.preroll.url)
			end if
		end if

		' Start playing video
		if playContent then
			m.loadingIndicator.control = "stop"
			print "[Main] Playing video"

                        ' if live stream, set position at end of stream
                        ' roku video player does not automatically detect if live stream
                        if screen.content.onAir = true
                          m.videoPlayer.content.live = true
                          m.videoPlayer.content.playStart = 100000000000
                          m.videoPlayer.enableTrickPlay = false
                        else
                          m.videoPlayer.enableTrickPlay = true
                        end if

			m.videoPlayer.visible = true
			screen.videoPlayerVisible = true

			if m.LoadingScreen.visible = true
			  EndLoader()
			end if

			m.currentVideoInfo = playerInfo.video

			m.videoPlayer.setFocus(true)
			m.videoPlayer.control = "play"
		else
		  CloseVideoPlayer()
		  m.currentVideoInfo = invalid
		end if ' end of if playContent
    end if
end sub

sub PrepareVideoPlayerWithSubtitles(screen, subtitleEnabled, playerInfo)
	' show loading indicator before requesting ad and playing video
	m.loadingIndicator.control = "start"
	m.on_air = screen.content.onAir

	m.VideoPlayer = screen.VideoPlayer
	m.VideoPlayer.observeField("position", m.port)
	m.videoPlayer.content = screen.content

  video_service = VideoService()

	if subtitleEnabled
	  m.videoPlayer.content.subtitleTracks = video_service.GetSubtitles(playerInfo)
	else
	  m.videoPlayer.content.subtitleTracks = []
	end if

	m.VideoPlayer.seek = m.VideoPlayer.seek
end sub

sub handleMidrollAd()
	currPos = m.videoPlayer.position

	timeDiff = Abs(m.midroll_ads[0].offset - currPos)
	print "Next midroll ad: "; m.midroll_ads[0].offset
	print "Time until next midroll ad: "; timeDiff

	' Within half second of next midroll ad timing
	if timeDiff <= 0.500
	  m.videoPlayer.control = "stop"

	  finished_ad = m.raf_service.playAds(m.currentVideoInfo, m.midroll_ads[0].url)

	  if finished_ad = false then CloseVideoPlayer()

	  ' Remove midroll ad from array
	  m.midroll_ads.shift()

	  ' Start playing video at back from currPos just before midroll ad started
	  m.videoPlayer.seek = currPos
	  m.akamai_service.setPlayStartedOnce(true)
	  m.videoPlayer.control = "play"

	' In case they fast forwarded or resumed watching, remove unnecessary midroll ads
	' Keep removing the first midroll ad in array until no midroll ads before current position
	else if m.midroll_ads.count() > 0 and currPos > m.midroll_ads[0].offset
	  while m.midroll_ads.count() > 0 and currPos > m.midroll_ads[0].offset
		m.midroll_ads.shift()
	  end while
	else if m.videoPlayer.visible = false
	  m.videoPlayer.control = "none"
	  m.midroll_ads = invalid
	  m.currentVideoInfo = invalid
	end if
end sub

sub CloseVideoPlayer()
  m.detailsScreen.videoPlayer.visible = false
  m.detailsScreen.videoPlayer.setFocus(false)
  m.detailsScreen.videoPlayerVisible = false

  if m.LoadingScreen.visible = true
    EndLoader()
  end if

  m.detailsScreen.visible = true
  m.detailsScreen.setFocus(true)
end sub

sub CreateVideoUnavailableDialog(errorMessage as String)
  dialog = createObject("roSGNode", "Dialog")
  dialog.title = ""
  dialog.optionsDialog = true
  dialog.message = errorMessage
  dialog.buttons = ["OK"]
  dialog.focusButton = 0
  m.scene.dialog = dialog
end sub

sub SearchQuery(SearchString as String)
    m.scene.searchContent = ParseContent(GetSearchContent(SearchString))
end sub

function GetSearchContent(SearchString as String)
    list = []

    favs = GetFavoritesIDs()

    row = {}
    row.Title = "Search results"
    row.ContentList = []

    params = {}
    params.AddReplace("q", SearchString)
    params.AddReplace("dpt", "true")
    videos = []
    video_index = 0
    for each video in GetVideos(params)
        video.inFavorites = favs.DoesExist(video._id)
        video.playlist_id = 0
        video.playlist_name = invalid
        video.video_index = video_index
        videos.push(CreateVideoObject(video))
        video_index = video_index + 1
    end for
    row.ContentList = videos

    if videos.count() = 0
        m.scene.ResultsText = "No results found..."
    else
        m.scene.ResultsText = ""
    end if

    list.Push(row)

    return list
end function

function GetFavoritesIDs()
    videoFavs = {}

    if m.global.favorites_via_api = true and m.global.auth.isLoggedIn
        user_info = m.current_user.getInfo()
        oauth_info = m.current_user.getOAuth()

        videoFavorites = GetVideoFavorites(user_info._id, {"access_token": oauth_info.access_token, "per_page": "100"})

        ' print videoFavorites
        if videoFavorites <> invalid
            if videoFavorites.count() > 0
                for each fav in videoFavorites
                    videoFavs.AddReplace(fav.video_id, fav._id)
                end for
            end if
        end if

    else
        favorite_ids = m.favorites_storage_service.GetFavoritesIDs()

        for each id in favorite_ids
            videoFavs.AddReplace(id, id)
        end for
    end if

    return videoFavs
end function

function GetFavoritesContent()
    list = []

    favs = GetFavoritesIDs()

    if m.global.favorites_via_api = true and m.global.auth.isLoggedIn
        user_info = m.current_user.getInfo()
        oauth_info = m.current_user.getOAuth()

        videoFavorites = GetVideoFavorites(user_info._id, {"access_token": oauth_info.access_token, "per_page": "100"})

        if videoFavorites <> invalid
            if videoFavorites.count() > 0
                row = {}
                row.title = m.global.labels.favorite_screen_label
                row.ContentList = []
                video_index = 0
                for each fav in videoFavorites
                    vid = GetVideo(fav.video_id)
                    if vid._id <> invalid and favs.DoesExist(vid._id)
                        vid.inFavorites = favs.DoesExist(vid._id)
                        vid.video_index = video_index
                        row.ContentList.push(CreateVideoObject(vid))
                        video_index = video_index + 1
                    end if
                end for
                list.push(row)
            end if
        end if
    else
        if favs.count() > 0
            row = {}
            row.title = m.global.labels.favorite_screen_label
            row.ContentList = []
            video_index = 0
            for each id in favs
                vid = GetVideo(id)
                if vid._id <> invalid and favs.DoesExist(vid._id)
                    vid.inFavorites = true
                    vid.video_index = video_index
                    row.ContentList.push(CreateVideoObject(vid))
                    video_index = video_index + 1
                end if
            end for
            list.push(row)
        end if
    end if

    return list
end function

function GetMyLibraryContent(is_linked as boolean, page = 1 as integer)
    list = []

    if is_linked
        oauth = m.current_user.getOAuth()

        video_entitlements = GetEntitledVideos({
            access_token: oauth.access_token,
            per_page: 20,
            page: page
            sort: "created_at",
            order: "desc"
        })

        row = { title: "", ContentList: [] }

        if video_entitlements <> invalid
            if video_entitlements.count() > 0
                row.title = m.global.labels.my_library_catalog_message
                favs = GetFavoritesIDs()
                video_index = 0
                for each entitled_vid in video_entitlements
                    vid = GetVideo(entitled_vid.video_id)
                    if vid._id <> invalid
                        vid.inFavorites = favs.DoesExist(vid._id)
                        vid.video_index = video_index
                        row.ContentList.push(CreateVideoObject(vid))
                        video_index = video_index + 1
                    end if
                end for
            else
                row.title = m.global.labels.empty_my_library_catalog_message
            end if
        end if

        list.push(row)
    else
        row = {
            title: m.global.labels.my_library_signin_message,
            contentList: []
        }
        list.push(row)
    end if

    return list
end function

Function ParseContent(list As Object)

    RowItems = createObject("RoSGNode","ContentNode")

    for each rowAA in list
        row = createObject("RoSGNode","ContentNode")
        row.Title = rowAA.Title

        for each itemAA in rowAA.ContentList
            item = createObject("RoSGNode","VideoNode")

            ' We don't use item.setFields(itemAA) as doesn't cast streamFormat to proper value
            for each key in itemAA
                item[key] = itemAA[key]
            end for

            row.appendChild(item)
        end for

        RowItems.appendChild(row)
    end for

    return RowItems
End Function

Function GetContent()
    rowTitles = GetCategory(m.app.category_id).values
    categoryTitle = GetCategory(m.app.category_id).title
    query = "category[" + categoryTitle + "]"

    favs = GetFavoritesIDs()

    list = []
    for each item in rowTitles
        row = {}
        row.title = item
        params = {}
        params.AddReplace(query, item)
        params.AddReplace("dpt", "true")
        videos = []
        video_index = 0
        for each video in GetVideos(params)
            video.inFavorites = favs.DoesExist(video._id)
            video.playlist_id = 0
            video.playlist_name = invalid
            video.video_index = video_index
            videos.push(CreateVideoObject(video))
            video_index = video_index + 1
        end for

        row.ContentList = videos
        list.push(row)
    end for

    return list
End Function

function GetPlaylistContent(playlist_id as String)
    pl = GetPlaylists({"id": playlist_id})[0]

    favs = GetFavoritesIDs()

    if pl.playlist_item_count > 0 then
        list = []
        row = {}
        row.title = pl.title
        videos = []
        video_index = 0
        for each video in GetPlaylistVideos(pl._id, {"dpt": "true", "per_page": m.app.per_page})
            video.inFavorites = favs.DoesExist(video._id)
            video.playlist_id = 0
            video.playlist_name = invalid
            video.video_index = video_index

            if pl.thumbnail_layout = "poster"
              video.usePoster = true
            else
              video.usePoster = false
            end if

            videos.push(CreateVideoObject(video))
            video_index = video_index + 1
        end for
        row.ContentList = videos

        list.push(row)
        m.videosList.push(videos)
        return list
    else
        return GetContentPlaylists(pl._id)
    end if
end function

function GetContentPlaylists(parent_id as String)
    ' parent_id = parent_id.tokenize(":")[0]
    if m.app.per_page <> invalid
      per_page = m.app.per_page
    else
      per_page = 500
    end if

    rawPlaylists = GetPlaylists({"parent_id": parent_id, "dpt": "true", "sort": "priority", "order": "dsc", "per_page": per_page, "page": 1})

    list = []
    row = {}
    row.title = "Playlists"
    row.ContentList = []
    for each item in rawPlaylists
        row.ContentList.push(CreatePlaylistObject(item))
    end for

    list.push(row)

    return list
end function

function GetPlaylistsAsRows(parent_id as String, thumbnail_layout = "")
    m.videosList = []

    ' parent_id = parent_id.tokenize(":")[0]
    if m.app.per_page <> invalid
      per_page = m.app.per_page
    else
      per_page = 500
    end if

    m.playlistsRowItemSizes = []
    m.playlistRowsSpacings = []

    rawPlaylists = GetPlaylists({"parent_id": parent_id, "dpt": "true", "sort": "priority", "order": "dsc", "per_page": per_page, "page": 1})

    favs = GetFavoritesIDs()

    ' the case where the playlist does not have any more children. that means it is a video playlist
    if rawPlaylists.count() = 0
      if thumbnail_layout = "poster"
        m.playlistsRowItemSizes.push( [ 147, 262 ] )
        m.playlistrowsSpacings.push( 50 )
      else
        m.playlistsRowItemSizes.push( [ 262, 147 ] )
        m.playlistrowsSpacings.push( 0 )
      end if

      return GetPlaylistContent(parent_id)
    end if

    list = []
    for each item in rawPlaylists
        row = {}
        row.title = item.title
        row.ContentList = []
        if item.playlist_item_count > 0
            row.ContentList = []
            videos = []

            if item.thumbnail_layout = "poster"
              m.playlistsRowItemSizes.push( [ 147, 262 ] )
              m.playlistrowsSpacings.push( 50 )
            else
              m.playlistsRowItemSizes.push( [ 262, 147 ] )
              m.playlistrowsSpacings.push( 0 )
            end if

            video_index = 0
            for each video in GetPlaylistVideos(item._id, {"per_page": m.app.per_page})
                if item.thumbnail_layout = "poster"
                  video.usePoster = true
                else
                  video.usePoster = false
                end if

                video.inFavorites = favs.DoesExist(video._id)
                video.playlist_id = item._id
                video.playlist_name = item.title
                video.video_index = video_index
                videos.push(CreateVideoObject(video))
                video_index = video_index + 1
            end for
            row.ContentList = videos
            m.videosList.push(videos)
        else
            m.playlistsRowItemSizes.push( [ 262, 147 ] )
            m.playlistrowsSpacings.push( 0 )

            pls = GetPlaylists({"parent_id": item._id, "dpt": "true", "sort": "priority", "order": "dsc", "per_page": per_page, "page": 1})
            for each pl in pls
                row.ContentList.push(CreatePlaylistObject(pl))
            end for
            m.videosList.push(row.ContentList)
        end if
        list.push(row)
    end for
  	m.playlistRows = list
    return list
end function

'///////////////////////////////////
' LabelList click handlers go here
'///////////////////////////////////
function handleButtonEvents(index, screen)
    button_role = screen.itemSelectedRole
    button_target = screen.itemSelectedTarget

    ? chr(10)
    ? tab(4) "main >>> handleButtonEvents()"
    ? tab(4) "screen: "; screen.id
    ? tab(4) "button role: "; button_role
    ? tab(4) "button target: "; button_target
    ? chr(10)

    if button_role = "play"
      RemakeVideoPlayer(screen)
      m.VideoPlayer = screen.VideoPlayer

      RemoveVideoIdForResumeFromReg(screen.content.id)
      m.akamai_service.setPlayStartedOnce(true)
      playRegularVideo(screen)
    else if button_role = "resume"
      resume_time = GetVideoIdForResumeFromReg(screen.content.id)
      RemakeVideoPlayer(screen)

      m.VideoPlayer = screen.VideoPlayer
      m.VideoPlayer.seek = resume_time
      playRegularVideo(screen)
    else if button_role = "favorite"
      markFavoriteButton(screen)
    else if button_role = "swaf"
      m.scene.transitionTo = "AuthSelection"
    else if button_role = "device_linking"
      m.DeviceLinking.show = true

    else if button_role = "signout"
      user_info = m.current_user.getInfo()
      pin = GetPin(GetUdidFromReg())
      if user_info.linked then UnlinkDevice(user_info._id, pin, {})

      LogOut()
      user_info = m.current_user.getInfo()
      m.auth_state_service.updateAuthWithUserInfo(user_info)

      m.AccountScreen.resetText = true

      m.scene.gridContent = m.gridContent

      m.scene.goBackToNonAuth = true

      ' Reset details screen buttons
      m.detailsScreen.content = m.detailsScreen.content

      sleep(500)
      CreateDialog(m.scene, "Success", "You have been signed out.", ["Close"])
    else if button_role = "submitCredentials" and screen.id = "SignInScreen"

      if screen.email = ""
        sleep(500)
        CreateDialog(m.scene, "Error", "Email is empty", ["Close"])
      else if screen.password = ""
        sleep(500)
        CreateDialog(m.scene, "Error", "Password is empty", ["Close"])
      else

        if screen.email <> "" and screen.password <> "" then login_response = Login(GetApiConfigs().client_id, GetApiConfigs().client_secret, screen.email, screen.password) else login_response = invalid

        if login_response <> invalid
          m.SignInScreen.reset = true

          user_info = m.current_user.getInfo()
          m.auth_state_service.updateAuthWithUserInfo(user_info)

          m.scene.gridContent = m.gridContent

          ' m.scene.transitionTo = "AccountScreen"
          m.scene.goBackToNonAuth = true

          ' Reset details screen
          m.detailsScreen.content = m.detailsScreen.content

          sleep(500)
          CreateDialog(m.scene, "Success", "Signed in as: " + user_info.email, ["Close"])
        else
          sleep(500)
          CreateDialog(m.scene, "Error", "Could not find user with that email and password.", ["Close"])
        end if

      end if ' end of email/password validation

    else if button_role = "submitCredentials" and screen.id = "SignUpScreen"
      if screen.email = ""
        CreateDialog(m.scene, "Error", "Email is empty. Cannot create account", ["Close"])
      else if screen.password = ""
        CreateDialog(m.scene, "Error", "Password is empty. Cannot create account", ["Close"])
      else
        StartLoader()
        create_consumer_response = CreateConsumer({ "consumer[email]": screen.email, "consumer[password]": screen.password, "consumer[name]": "" })

        if create_consumer_response <> invalid
          login_response = Login(GetApiConfigs().client_id, GetApiConfigs().client_secret, screen.email, screen.password)

          user_info = m.current_user.getInfo()
          m.auth_state_service.updateAuthWithUserInfo(user_info)

          m.SignUpScreen.reset = true
          m.scene.goBackToNonAuth = true

          handleNativeToUniversal()
        else
          EndLoader()
          m.SignUpScreen.setFocus(true)
          m.SignUpScreen.findNode("SubmitButton").setFocus(true)

          CreateDialog(m.scene, "Error", "It appears that email was taken.", ["Close"])
        end if

      end if

    else if button_role = "syncNative"
      user_info = m.current_user.getInfo()
      latest_native_sub = m.roku_store_service.latestNativeSubscriptionPurchase()

      third_party_id = GetPlan(latest_native_sub.code, {}).third_party_id

      bifrost_params = {
        app_key: GetApiConfigs().app_key,
        consumer_id: user_info._id,
        third_party_id: third_party_id,
        roku_api_key: GetApiConfigs().roku_api_key,
        transaction_id: UCase(latest_native_sub.purchaseId),
        device_type: "roku"
      }

      native_sub_status = GetNativeSubscriptionStatus(bifrost_params)

      if native_sub_status <> invalid and native_sub_status.is_valid <> invalid and native_sub_status.is_valid

        updated_user_info = m.current_user.getInfo()

        ' native subscription sync success
        if updated_user_info.subscription_count > 0
          ' Re-login. Get new access token
          if updated_user_info.linked then GetAndSaveNewToken("device_linking") else GetAndSaveNewToken("login")
          m.auth_state_service.updateAuthWithUserInfo(updated_user_info)

          ' Refresh lock icons with grid screen content callback
          m.scene.gridContent = m.gridContent

          m.AccountScreen.resetText = true

          ' details screen should update self
          m.detailsScreen.content = m.detailsScreen.content

          m.native_email_storage.WriteEmail(updated_user_info.email)

          sleep(500)
          CreateDialog(m.scene, "Success", "Was able to validate subscription.", ["Close"])

        ' subscription count = 0
        else

          stored_email = m.native_email_storage.ReadEmail()
          if stored_email = "" or stored_email = invalid then message = "Please sign in with the correct email to sync your subscription." else message = "Please sign in as " + stored_email + " to sync your subscription."

          sleep(500)
          CreateDialog(m.scene, "Error", message, ["Close"])
        end if

      else
        sleep(500)
        CreateDialog(m.scene, "Error", "There was an error validating your subscription.", ["Close"])
      end if


    else if button_role = "transition" and button_target = "AuthSelection"
      m.scene.transitionTo = "AuthSelection"
    else if button_role = "transition" and button_target = "UniversalAuthSelection"
      if m.global.enable_device_linking = false then m.scene.transitionTo = "SignInScreen" else m.scene.transitionTo = "UniversalAuthSelection"
    else if button_role = "transition" and button_target = "DeviceLinking"
      m.DeviceLinking.show = true
      m.DeviceLinking.setFocus(true)
    else if button_role = "transition" and button_target = "SignInScreen"
      m.scene.transitionTo = "SignInScreen"
    end if
end function

function handleNativeToUniversal() as void
  m.AuthSelection.visible = false
  StartLoader()

  ' Get updated user info
  user_info = m.current_user.getInfo()
  m.auth_state_service.updateAuthWithUserInfo(user_info)

  plan = m.AuthSelection.currentPlanSelected

  order = [{
    code: plan.code,
    qty: 1
  }]

  ' Make nsvod purchase
  purchase_subscription = m.roku_store_service.makePurchase(order)
  EndLoader()
  m.AuthSelection.visible = true
  m.AuthSelection.setFocus(true)

  if purchase_subscription.success
      m.auth_state_service.incrementNativeSubCount()

      if m.global.native_to_universal_subscription = true
        ' Store email used for purchase. For sync subscription later
        m.native_email_storage.DeleteEmail()
        m.native_email_storage.WriteEmail(user_info.email)

        ' Get recent purchase
        recent_purchase = purchase_subscription.receipt

        third_party_id = GetPlan(recent_purchase.code, {}).third_party_id

        bifrost_params = {
          app_key: GetApiConfigs().app_key,
          consumer_id: user_info._id,
          third_party_id: third_party_id,
          roku_api_key: GetApiConfigs().roku_api_key,
          transaction_id: UCase(recent_purchase.purchaseId),
          device_type: "roku"
        }

        ' Check is subscription went through with BiFrost. BiFrost should validate then create universal subscription
        native_sub_status = GetNativeSubscriptionStatus(bifrost_params)

        if native_sub_status <> invalid and native_sub_status.is_valid <> invalid and native_sub_status.is_valid
            user_info = m.current_user.getInfo()

            ' Create new access token. Creating sub does not update entitlements for access tokens created before subscription
            if user_info.linked then GetAndSaveNewToken("device_linking") else GetAndSaveNewToken("login")
            m.auth_state_service.updateAuthWithUserInfo(user_info)

            current_native_plan = m.roku_store_service.latestNativeSubscriptionPurchase()
            m.auth_state_service.setCurrentNativePlan(current_native_plan)

            ' Refresh lock icons with grid screen content callback
            m.scene.gridContent = m.gridContent

            m.scene.goBackToNonAuth = true

            ' details screen should update self
            m.detailsScreen.content = m.detailsScreen.content

            EndLoader()

            sleep(500)
            CreateDialog(m.scene, "Welcome", "Hi, " + user_info.email + ". Thanks for signing up.", ["Close"])

        ' Bifrost verification failed
        else
            EndLoader()
            sleep(500)
            CreateDialog(m.scene, "Error", "Could not verify your purchase with Roku. You can cancel your subscription on the Roku website.", ["Close"])
        end if ' native_sub_status.valid

      ' regular nsvod
      else
        EndLoader()
        current_native_plan = m.roku_store_service.latestNativeSubscriptionPurchase()
        m.auth_state_service.setCurrentNativePlan(current_native_plan)

        ' Refresh lock icons with grid screen content callback
        m.scene.gridContent = m.gridContent

        m.scene.goBackToNonAuth = true

        ' details screen should update self
        m.detailsScreen.content = m.detailsScreen.content

        sleep(500)
        CreateDialog(m.scene, "Success", "Thank you for purchasing the subscription.", ["Dismiss"])
      end if ' end if global.native_to_universal_subscription

  ' User cancelled purchase or error from Roku store
  else
    m.AuthSelection.findNode("Plans").setFocus(true)
    CreateDialog(m.scene, "Incomplete", "Was not able to complete purchase. Please try again later.", ["Close"])
  end if
end function


' Seting details screen's RemakeVideoPlayer value to true recreates Video component
'     Roku Video component performance degrades significantly after multiple uses, so we make a new one
function RemakeVideoPlayer(screen) as void
    screen.RemakeVideoPlayer = true
    screen.VideoPlayer.seek = 0.0
end function

Function StartLoader()
    m.LoadingScreen.show = true
    m.LoadingScreen.setFocus(true)
    m.loadingIndicator1.control = "start"
End Function

Function EndLoader()
    m.loadingIndicator1.control = "stop"
    m.LoadingScreen.show = false
    m.LoadingScreen.setFocus(false)
    m.detailsScreen.setFocus(true)
End Function

Function markFavoriteButton(lclScreen)
    id = lclScreen.content.id
    in_favorites = lclScreen.content.inFavorites

    if m.global.favorites_via_api = true
        if m.global.auth.isLoggedIn
            favs = GetFavoritesIDs()
            user_info = m.current_user.getInfo()
            oauth_info = m.current_user.getOAuth()

            if in_favorites
                DeleteVideoFavorite(user_info._id, favs[id], {"access_token": oauth_info.access_token, "video_id": id, "_method": "delete"})
                m.favorites_management_service.RemoveFavorite(id)
                lclScreen.content.inFavorites = false

            else
                CreateVideoFavorite(user_info._id, {"access_token": oauth_info.access_token, "video_id": id })
                m.favorites_management_service.AddFavorite(id)
                lclScreen.content.inFavorites = true
            end if

        ' Not authenicated. Trying to favorite when favorites_via_api is on
        else
            dialog = createObject("roSGNode", "Dialog")
            dialog.title = "Link Your Device"
            dialog.optionsDialog = true
            dialog.message = "Please link your device in order to add this video to favorites."
            dialog.buttons = ["OK"]
            m.scene.dialog = dialog
        end if

    ' local favorites
    else
        if in_favorites
            m.favorites_storage_service.DeleteFavorite(id)
            m.favorites_management_service.RemoveFavorite(id)
            lclScreen.content.inFavorites = false
        else
            m.favorites_storage_service.AddFavorite(id)
            m.favorites_management_service.AddFavorite(id)
            lclScreen.content.inFavorites = true
        end if
    end if
End Function

' ////////////////////////////////////////////////////////////////////////////////////////////////////////////
'   Called at startup. Sets up m.global.theme and m.global.brand_color
'   Accepts theme and brand color from app settings, otherwise accepts from config file.
'
'   If you want to customize your theme, you can:
'     1- set the "theme" inside the config file to "custom"
'     2- edit CustomTheme() inside source/themes.brs
'     3- add/update the images inside the images folder
Function SetTheme()

  if m.app.theme <> invalid
    theme = m.app.theme

    if GetApiConfigs().theme = "custom" then theme = "custom"
  else
    theme = GetApiConfigs().theme
  end if

  if m.app.brand_color <> invalid
    brand_color = m.app.brand_color
  else
    brand_color = GetApiConfigs().brand_color
  end if

  if m.global <> invalid
    m.global.addFields({ brand_color: brand_color })

    if theme = "dark"
      m.global.addFields({ theme: DarkTheme() })
    else if theme = "light"
      m.global.addFields({ theme: LightTheme() })
    else if theme = "custom"
      m.global.addFields({ theme: CustomTheme() })
    end if
  end if
End Function

function SetMonetizationSettings() as void
  if m.app <> invalid
    m.global.addFields({
      avod: m.app.avod,
      in_app_purchase: m.app.in_app_purchase,
      device_linking: m.app.device_linking
    })
  end if
end function

' Called at startup. Sets feature flags from config file
function SetFeatures() as void
  configs = GetApiConfigs()

  m.global.addFields({
    autoplay: m.app.autoplay,
    swaf: m.app.subscribe_to_watch_ad_free,
    enable_lock_icons: m.app.enable_lock_icons,
    native_to_universal_subscription: m.app.native_to_universal_subscription,
    favorites_via_api: m.app.favorites_via_api,
    universal_tvod: m.app.universal_tvod,
    enable_device_linking: configs.enable_device_linking,
    test_info_screen: configs.test_info_screen
  })
end function

' Called at startup. Sets up m.global.auth
function SetGlobalAuthObject() as void
  current_user_info = m.current_user.getInfo()
  if current_user_info._id <> invalid and current_user_info._id <> "" then is_logged_in = true else is_logged_in = false
  if current_user_info.email <> invalid then user_email = current_user_info.email else user_email = ""

  native_sub_purchases = m.roku_store_service.getUserNativeSubscriptionPurchases()

  valid_native_subs = []

  if current_user_info.subscription_count <> invalid then universal_sub_count = current_user_info.subscription_count else universal_sub_count = 0

  if m.global.native_to_universal_subscription = false
    valid_native_subs = m.roku_store_service.getUserNativeSubscriptionPurchases()
  end if

  m.global.addFields({ auth: {
    nativeSubCount: valid_native_subs.count(),
    universalSubCount: universal_sub_count,
    isLoggedIn: is_logged_in,
    isLinked: current_user_info.linked,
    email: user_email
  } })


  ' If active natve plan, set plan
  latest_native_sub = m.roku_store_service.latestNativeSubscriptionPurchase()

  m.global.addFields({ nsvod: {
    currentPlan: latest_native_sub
  } })
end function

function SetVersion() as void
    if m.global <> invalid then m.global.addFields({ version: GetApiConfigs().version })
end function

function SetTextLabels() as void
    if m.global <> invalid
        text_configs = GetTextConfigs()

        labels = {}
        for each label in text_configs
            labels[label] = text_configs[label]
        end for

        m.global.addFields({ labels: labels })
    end if
end function
