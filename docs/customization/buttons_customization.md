# Buttons Customization

Most buttons in the SDK are created using as a `ButtonNode` which is an extension of the `ContentNode` for the Roku Scenegraph. Each `ButtonNode` accepts a `role` and `target` field, as well as the regular fields for a `ContentNode`. The ButtonNodes are passed as a one dimension ContentNode into a <a href="https://sdkdocs.roku.com/display/sdkdoc/LabelList" target="_blank">LabelList</a>.

### Customizing Button Text and Behavior

The logic for how buttons clicks are handled are in primarily in `handleButtonEvents(), inside source/main.brs` and `OnMenuButtonSelected(), inside components/screens/HomeScene/HomeScene.brs`. `OnMenuButtonSelected()` handles the button clicks from the menu, while `handleButtonEvents()` is every other button click.

The most important fields for a ButtonNode are `title` and `role`. `title` is what text will show for the button. `role` determines what the button is supposed to do and the logic for how the role is handled is inside 2 functions mentioned above.

The most common button you may see is the `"transition"` button which lets you transition to different parts in the app. When the button's `role` is `"transition"`, the functions above look at the `target` field to determine what to transition to. `target` is the `id` of the component that you want to show. If you want to change how the app handles these transitions you can update the functions mentioned above.

If you want to change which buttons appear, you will need to update the component's BrightScript file. Most of the components are organized inside the `components/screens` folder. For example, if I wanted to update the Menu buttons I would go into `components/screens/Menu/Menu.brs` to make my changes.

### Customizing Button Appearance

If you want to update the appearance of the buttons, you can update the component that the button appears in. The component's XML file is where you create the view. You can determine appears and set values like text size and color. There are many ways to create buttons within Roku Scenegraph, but most of the buttons in this SDK use the LabelList.

You can also set change the appearance inside the component's BrightScript file. The BrightScript file is like the component's controller and handles how the component behaves with different user input. The buttons can be referenced inside this file and have their fields updated, so the fields inside the XML file are not final. As an example, this is where the dynamic values (colors) of the components can be set.