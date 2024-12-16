local AddonName, NS = ...

local CopyTable = CopyTable

NS.AceConfig = {
  name = AddonName,
  type = "group",
  args = {
    spacer1 = {
      name = " ",
      type = "description",
      order = 0,
    },
    description = {
      name = "Personal MMR only exists in Solo Shuffle/Blitz.\nFor 2v2, 3v3, and RBG you'll see Rating instead of MMR.",
      type = "description",
      fontSize = "medium",
      order = 1,
    },
    spacer2 = {
      name = "",
      type = "description",
      order = 2,
    },
    show2v2 = {
      name = "Show 2v2 Rating",
      type = "toggle",
      width = "full",
      order = 3,
      set = function(_, val)
        NS.db.global.show2v2 = val
        NS.OnDbChanged()
      end,
      get = function(_)
        return NS.db.global.show2v2
      end,
    },
    show3v3 = {
      name = "Show 3v3 Rating",
      type = "toggle",
      width = "full",
      order = 4,
      set = function(_, val)
        NS.db.global.show3v3 = val
        NS.OnDbChanged()
      end,
      get = function(_)
        return NS.db.global.show3v3
      end,
    },
    showRBG = {
      name = "Show RBG Rating",
      type = "toggle",
      width = "full",
      order = 5,
      set = function(_, val)
        NS.db.global.showRBG = val
        NS.OnDbChanged()
      end,
      get = function(_)
        return NS.db.global.showRBG
      end,
    },
    showShuffle = {
      name = "Show Shuffle MMR",
      type = "toggle",
      width = 1.0,
      order = 6,
      set = function(_, val)
        NS.db.global.showShuffle = val
        NS.OnDbChanged()
      end,
      get = function(_)
        return NS.db.global.showShuffle
      end,
    },
    showShuffleRating = {
      name = "Show Rating instead of MMR",
      type = "toggle",
      width = 2.0,
      order = 7,
      set = function(_, val)
        NS.db.global.showShuffleRating = val
        NS.OnDbChanged()
      end,
      get = function(_)
        return NS.db.global.showShuffleRating
      end,
    },
    spacer3 = {
      name = "",
      type = "description",
      order = 8,
    },
    showBlitz = {
      name = "Show Blitz MMR",
      type = "toggle",
      width = 1.0,
      order = 9,
      set = function(_, val)
        NS.db.global.showBlitz = val
        NS.OnDbChanged()
      end,
      get = function(_)
        return NS.db.global.showBlitz
      end,
    },
    showBlitzRating = {
      name = "Show Rating instead of MMR",
      type = "toggle",
      width = 2.0,
      order = 10,
      set = function(_, val)
        NS.db.global.showBlitzRating = val
        NS.OnDbChanged()
      end,
      get = function(_)
        return NS.db.global.showBlitzRating
      end,
    },
    tableGroup = {
      name = "Table Settings",
      type = "group",
      inline = true,
      order = 11,
      args = {
        showSpecIcon = {
          name = "Show Spec Icon instead of Spec Name",
          type = "toggle",
          width = "double",
          order = 1,
          set = function(_, val)
            NS.db.global.showSpecIcon = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.showSpecIcon
          end,
        },
      },
    },
    generalGroup = {
      name = "General Settings",
      type = "group",
      inline = true,
      order = 12,
      args = {
        lock = {
          name = "Lock the text into place",
          desc = "While unlocked you can move around the text or right click open settings.",
          type = "toggle",
          width = "double",
          order = 1,
          set = function(_, val)
            NS.db.global.lock = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.lock
          end,
        },
        showMMRDifference = {
          name = "Show gains/losses",
          desc = "Shows before and after values as well as +/- amounts.",
          type = "toggle",
          width = "double",
          order = 2,
          set = function(_, val)
            NS.db.global.showMMRDifference = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.showMMRDifference
          end,
        },
        showOnlyInQueue = {
          name = "Show only in queue",
          desc = "Only show the text when you're in a queue.",
          type = "toggle",
          width = "double",
          order = 3,
          set = function(_, val)
            NS.db.global.showOnlyInQueue = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.showOnlyInQueue
          end,
        },
        showInInstances = {
          name = "Show in instances",
          desc = "Show the text while in an instance.",
          type = "toggle",
          width = "double",
          order = 4,
          set = function(_, val)
            NS.db.global.showInInstances = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.showInInstances
          end,
        },
        hideNoResults = {
          name = "Hide all 'No data yet' text",
          desc = "When there is no data available yet for a given bracket we show 'No data yet' text.",
          type = "toggle",
          width = "double",
          order = 5,
          set = function(_, val)
            NS.db.global.hideNoResults = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.hideNoResults
          end,
        },
        hideMinimapIcon = {
          name = "Hide minimap icon",
          desc = "Hides the minimap icon.",
          type = "toggle",
          width = "double",
          order = 6,
          set = function(_, val)
            NS.db.minimap.hide = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.minimap.hide
          end,
        },
        fontSize = {
          name = "Font Size",
          type = "range",
          width = "double",
          order = 7,
          min = 8,
          max = 120,
          step = 1,
          set = function(_, val)
            NS.db.global.fontSize = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.fontSize
          end,
        },
        fontFamily = {
          name = "Font Family",
          type = "select",
          width = "double",
          order = 8,
          dialogControl = "LSM30_Font",
          values = AceGUIWidgetLSMlists.font,
          set = function(_, val)
            NS.db.global.fontFamily = val
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.fontFamily
          end,
        },
        color = {
          type = "color",
          name = "Color",
          width = "full",
          order = 9,
          hasAlpha = true,
          set = function(_, val1, val2, val3, val4)
            NS.db.global.color.r = val1
            NS.db.global.color.g = val2
            NS.db.global.color.b = val3
            NS.db.global.color.a = val4
            NS.OnDbChanged()
          end,
          get = function(_)
            return NS.db.global.color.r, NS.db.global.color.g, NS.db.global.color.b, NS.db.global.color.a
          end,
        },
        reset = {
          name = "Reset Everything",
          type = "execute",
          width = "normal",
          order = 100,
          func = function()
            MMRTrackerDB = CopyTable(NS.DefaultDatabase)
            NS.db = CopyTable(NS.DefaultDatabase)
            NS.OnDbChanged()
          end,
        },
      },
    },
  },
}
