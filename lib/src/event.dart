part of dquery;

// things to fix:
// 1. namespace, multiple types
// 2. focus/blur special handling
// 3. add/remove/trigger elem should accept Window?
// 4. guid removal problem
// 5. off()

// static helper class
class _EventUtil {
  
  static Set<String> _global = new HashSet<String>();
  
  // guid management
  static Map _handleGuid = new HashMap();
  static int _getGuid(handler) =>
      _handleGuid.putIfAbsent(handler, () => _guid++); // TODO: need a way to clean up
  static bool _hasGuid(handler) =>
      _handleGuid.containsKey(handler);
  static void _copyGuid(handler1, handler2) {
    if (!_hasGuid(handler1) && _hasGuid(handler2))
      _handleGuid[handler1] = _handleGuid[handler2];
  }
  
  static void add(Node elem, String types, DQueryEventListener handler, String selector, data) {
    
    final Map elemData = _dataPriv.getSpace(elem);
    // jQuery: Don't attach events to noData or text/comment nodes (but allow plain objects)
    // SKIPPED: will not happen as elem is guaranteed to be an Element
    // if (elemData == null) return;
    
    // jQuery: Make sure that the handler has a unique ID, used to find/remove it later
    final int g = _getGuid(handler); // TODO: need better management
    
    // jQuery: Init the element's event structure and main handler, if this is the first
    final Map<String, HandleObjectContext> events = 
        elemData.putIfAbsent('events', () => new HashMap<String, HandleObjectContext>());
    
    // the joint proxy handler
    final EventListener eventHandle = elemData.putIfAbsent('handle', () => (Event e) {
      if (e == null || _EventUtil._triggered != e.type)
        dispatch(elem, _EventUtil.fix(e));
      // jQuery: Discard the second event of a jQuery.event.trigger() and
      //         when an event is called after a page has unloaded
      /* src:
        return typeof jQuery !== undefined && (!e || jQuery.event.triggered !== e.type) ?
          jQuery.event.dispatch.apply( eventHandle.elem, arguments ) :
          undefined;
      */
    });
    
    // jQuery: Handle multiple events separated by a space
    for (String t in _splitTypes(types)) {
      
      // TODO: we should use the same code
      // caculate namespaces
      final int k = t.indexOf('.');
      String type = k < 0 ? t : t.substring(0, k);
      final String origType = type;
      final List<String> namespaces = k < 0 ? [] : t.substring(k + 1).split('.');
      
      // jQuery: There *must* be a type, no attaching namespace-only handlers
      if (type.isEmpty)
        continue;
      
      /*
      // jQuery: If event changes its type, use the special event handlers for the changed type
      SpecialEventHandling special = _getSpecial(type);
      // jQuery: If selector defined, determine special event api type, otherwise given type
      type = _fallback(selector != null ? special.delegateType : special.bindType, () => type);
      // jQuery: Update special based on newly reset type
      special = _getSpecial(type);
      */
      
      // jQuery: handleObj is passed to all event handlers
      final bool needsContext = selector != null && _EventUtil._NEEDS_CONTEXT.hasMatch(selector);
      HandleObject handleObj = 
          new HandleObject(g, selector, type, origType, namespaces.join('.'), needsContext, handler)
          ..data = data;
      
      // jQuery: Init the event handler queue if we're the first
      HandleObjectContext handleObjCtx = events.putIfAbsent(type, () {
        elem.$dom_addEventListener(type, eventHandle, false);
        return new HandleObjectContext();
      });
      
      // jQuery: Add to the element's handler list, delegates in front
      if (selector != null && !selector.isEmpty) {
        handleObjCtx.delegates.add(handleObj);
        
      } else {
        handleObjCtx.handlers.add(handleObj);
      }
      
      // jQuery: Keep track of which events have ever been used, for event optimization
      _global.add(type);
      
    }
    
  }
  
  static final RegExp _NEEDS_CONTEXT = new RegExp(r'^[\x20\t\r\n\f]*[>+~]');
  
  // jQuery: Detach an event or set of events from an element
  static void remove(Node elem, String types, DQueryEventListener handler, 
                     String selector, [bool mappedTypes = false]) {
    
    final Map elemData = _dataPriv.getSpace(elem);
    if (elemData == null)
      return;
    
    final Map<String, HandleObjectContext> events = elemData['events'];
    if (events == null)
      return;
    
    // jQuery: Once for each type.namespace in types; type may be omitted
    for (String t in _splitTypes(types)) {
      
      // caculate namespaces
      final int k = t.indexOf('.');
      String type = k < 0 ? t : t.substring(0, k);
      final String origType = type;
      final List<String> namespaces = k < 0 ? [] : t.substring(k + 1).split('.');
      
      // jQuery: Unbind all events (on this namespace, if provided) for the element
      if (type != null) {
        for (String t in events.keys) {
          remove(elem, "$type$t", handler, selector, true);
        }
        continue;
      }
      
      //SpecialEventHandling special = _getSpecial(type);
      //type = _fallback(selector != null ? special.delegateType : special.bindType, () => type);
      HandleObjectContext handleObjCtx = _fallback(events[type], () => HandleObjectContext.EMPTY);
      List<HandleObject> delegates = handleObjCtx.delegates;
      List<HandleObject> handlers = handleObjCtx.handlers;
      // TODO
      // src:tmp = tmp[2] && new RegExp( "(^|\\.)" + namespaces.join("\\.(?:.*\\.|)") + "(\\.|$)" );
      var tmp2;
      
      final int origCount = handlers.length;
      for (int j = origCount - 1; j >= 0; j--) {
        HandleObject handleObj = handlers[j];
        if ((mappedTypes || origType == handleObj.origType) &&
            (handler == null || (_hasGuid(handler) && _getGuid(handler) == handleObj.guid)) &&
            (tmp2 == null || tmp2.test(handleObj.namespace)) &&
            (selector == null || selector == handleObj.selector || selector == "**" && handleObj.selector != null)) {
          if (handleObj.selector != null)
            handleObjCtx.delegateCount--;
        }
      }
      
      // jQuery: Remove generic event handler if we removed something and no more handlers exist
      //         (avoids potential for endless recursion during removal of special event handlers)
      if (origCount > 0 && handlers.isEmpty) {
        events.remove(type);
      }
      
      // TODO: should deal with guid
      
    }
    
  }
  
  static List<String> _splitTypes(String types) {
    //src:types = ( types || "" ).match( core_rnotwhite ) || [""];
    return [types]; // TODO: fix
  }
  
  static void trigger(String type, data, Node elem, [bool onlyHandlers = false]) {
    _EventUtil.trigger0(new DQueryEvent(type, elem), data, onlyHandlers); // TODO: shall DQueryEvent eats data?
  }
  
  // TODO: elem need to be EventTarget, so it can accept Window?
  static void trigger0(DQueryEvent event, data, [bool onlyHandlers = false]) {
    
    Node elem = event.target;
    
    String type = event.type;
    List<String> namespaces;
    
    if (type.indexOf('.') >= 0) {
      namespaces = type.split('.');
      type = namespaces.removeAt(0);
      namespaces.sort();
    }
    
    //final String ontype = type.indexOf(':') < 0 ? "on$type" : null;
    
    if (elem == null) 
      elem = document;
    List<Node> eventPath = [elem];
    Window eventPathWindow = null;
    
    // jQuery: Don't do events on text and comment nodes
    if (elem.nodeType == 3 || elem.nodeType == 8)
      return;
    
    // jQuery: focus/blur morphs to focusin/out; ensure we're not firing them right now
    // TODO
    /* src:
    if ( rfocusMorph.test( type + jQuery.event.triggered ) ) {
      return;
    }
    */
    
    // jQuery: Caller can pass in a jQuery.Event object, Object, or just an event type string
    /* src:
    event = event[ jQuery.expando ] ?
        event : new jQuery.Event( type, typeof event === "object" && event );
    */
    //DQueryEvent dqevent = _fallback(event, () => new DQueryEvent(type)); // TODO
    
    // jQuery: Trigger bitmask: & 1 for native handlers; & 2 for jQuery (always true)
    event._isTrigger = onlyHandlers ? 2 : 3;
    if (namespaces != null)
      event._namespace = namespaces.join('.');
    // TODO
    /* src:
    event.namespace_re = event.namespace ?
        new RegExp( "(^|\\.)" + namespaces.join("\\.(?:.*\\.|)") + "(\\.|$)" ) : null;
    */
    
    // jQuery: Clean up the event in case it is being reused
    //dqevent.result = null;
    /*
    if (event._target == null)
      event._target = elem;
    */
    
    // TODO: how to combine data
    // jQuery: Clone any incoming data and prepend the event, creating the handler arg list
    // SKIPPED: javascript-specific
    // src:data = data == null ? [ event ] : jQuery.makeArray( data, [ event ] );
    
    // jQuery: Determine event propagation path in advance, per W3C events spec (#9951)
    //         Bubble up to document, then to window; watch for a global ownerDocument var (#9724)
    //String bubbleType = null;
    if (!onlyHandlers /*&& !special.noBubble && !_isWindow(elem)*/) {
      //bubbleType = type; //_fallback(special.delegateType, () => type);
      // TODO
      /* src:
      if ( !rfocusMorph.test( bubbleType + type ) ) {
        cur = cur.parentNode;
      }
      */
      
      Node tmp = elem;
      for (Node cur = elem; cur != null; cur = cur.parentNode) {
        eventPath.add(cur);
        tmp = cur;
      }
      
      // jQuery: Only add window if we got to document (e.g., not plain obj or detached DOM)
      /*
      if (tmp == _fallback(elem.ownerDocument, () => document))
        eventPathWindow = _fallback((tmp as Document).window, () => window);
      */
      
    }
    
    // jQuery: Fire handlers on the event path
    //bool first = true;
    for (Node n in eventPath) {
      if (event.isPropagationStopped)
        break;
      //dqevent._type = !first ? bubbleType : type; //_fallback(special.bindType, () => type);
      
      // jQuery: jQuery handler
      if (_getEvents(n).containsKey(event.type)) {
        // here we've refactored the implementation apart from jQuery
        _EventUtil.dispatch(n, event); 
      }
      
      //first = false;
    }
    /*
    if (eventPathWindow != null) {
      // TODO: how to get window data space from _dataPriv
    }
    */
    //event._type = type;
    
    // jQuery: If nobody prevented the default action, do it now
    if (!onlyHandlers && !event.isDefaultPrevented) {
      if (!(type == "click" && _nodeName(elem, "a"))) {
        // jQuery: Call a native DOM method on the target with the same name name as the event.
        // jQuery: Don't do default actions on window, that's where global variables be (#6170)
        
        if (/*ontype != null &&*/ _hasAction(elem, type)) {
          // jQuery: Prevent re-triggering of the same event, since we already bubbled it above
          _EventUtil._triggered = type;
          _performAction(elem, type);
          _EventUtil._triggered = null;
        }
      }
    }
  }
  
  static String _triggered;
  
  static void dispatch(Node elem, DQueryEvent dqevent) {
    
    final Map<String, HandleObjectContext> events = _getEvents(elem);
    final HandleObjectContext handleObjCtx = _getHandleObjCtx(elem, dqevent.type);
    
    dqevent._delegateTarget = elem;
    
    // jQuery: Determine handlers
    final List<_HandlerQueueEntry> handlerQueue = _EventUtil.handlers(elem, dqevent, handleObjCtx);
    
    // jQuery: Run delegates first; they may want to stop propagation beneath us
    for (_HandlerQueueEntry matched in handlerQueue) {
      if (dqevent.isPropagationStopped) break;
      dqevent._currentTarget = matched.elem;
      for (HandleObject handleObj in matched.handlers) {
        if (dqevent.isImmediatePropagationStopped) break;
        // jQuery: Triggered event must either 1) have no namespace, or
        //         2) have namespace(s) a subset or equal to those in the bound event (both can have no namespace).
        // TODO: fix for namespace
        if (true) {
          dqevent._handleObj = handleObj;
          dqevent.data = handleObj.data;
          handleObj.handler(dqevent);
        }
      }
    }
    
  }
  
  // TODO: check elem/dqevent.target variable DRY
  static List<_HandlerQueueEntry> handlers(Node elem, DQueryEvent dqevent, 
      HandleObjectContext handleObjCtx) {
    
    final List<_HandlerQueueEntry> handlerQueue = new List<_HandlerQueueEntry>();
    final List<HandleObject> delegates = handleObjCtx.delegates;
    final List<HandleObject> handlers = handleObjCtx.handlers;
    Node cur = dqevent.target;
    
    // jQuery: Find delegate handlers
    //         Black-hole SVG <use> instance trees (#13180)
    //         Avoid non-left-click bubbling in Firefox (#3861)
    // src: if ( delegateCount && cur.nodeType && (!event.button || event.type !== "click") ) {
    if (!delegates.isEmpty) { // TODO: fix
      
      for (; cur != elem; cur = _fallback(cur.parentNode, () => elem)) {
        
        // jQuery: Don't process clicks on disabled elements (#6911, #8165, #11382, #11764)
        // TODO: uncomment later
        /*
        if (dqevent.type == "click" && h.isDisabled(cur))
          continue;
        */
        
        final Map<String, bool> matches = new HashMap<String, bool>();
        final List<HandleObject> matched = new List<HandleObject>();
        for (HandleObject handleObj in delegates) {
          // jQuery: Don't conflict with Object.prototype properties (#13203)
          final String sel = "${trim(handleObj.selector)} ";
          if (matches.putIfAbsent(sel, () => handleObj.needsContext ? 
              new DQuery(sel, elem).contains(cur) : 
              ((cur is Element) && (cur as Element).matches(sel)))) { // TODO: need util to cover Document/Element?
            matched.add(handleObj);
          }
        }
        
        if (!matched.isEmpty) {
          handlerQueue.add(new _HandlerQueueEntry(cur, matched));
        }
        
      }
    }
    
    // jQuery: Add the remaining (directly-bound) handlers
    if (!handlers.isEmpty) {
      handlerQueue.add(new _HandlerQueueEntry(elem, handlers));
    }
    
    return handlerQueue;
    
  }
  
  static DQueryEvent fix(Event event) {
    // TODO: find properties to copy from fix hook
    final DQueryEvent dqevent = new DQueryEvent.from(event);
    
    // jQuery: Support: Chrome 23+, Safari?
    //         Target should not be a text node (#504, #13143)
    if (dqevent._target is Text)
      dqevent._target = (dqevent._target as Text).parentNode;
    
    // TODO: filter by fixHook
    return dqevent;
  }
  
  static Map<String, HandleObjectContext> _getEvents(Node elem) =>
      _fallback(_dataPriv.get(elem, 'events'), () => {});
  
  static HandleObjectContext _getHandleObjCtx(Node elem, String type) =>
      _fallback(_getEvents(elem)[type], () => HandleObjectContext.EMPTY);
  
  /* TODO: see what'd happen if we ignore special alltogether
  static SpecialEventHandling _getSpecial(String type) =>
      _fallback(_special[type], () => SpecialEventHandling.EMPTY);
  
  static Map<String, SpecialEventHandling> _special = new HashMap<String, SpecialEventHandling>.from({
    // jQuery: Prevent triggered image.load events from bubbling to window.load
    'load': new SpecialEventHandling()..noBubble = true,
    'click': new SpecialEventHandling()..trigger = (EventTarget elem, data) {
      // jQuery: For checkbox, fire native event so checked state will be right
      if (elem is Checkbox) {
        (elem as Checkbox).click();
        return false;
      }
      return true;
      
    },
    'focus': new SpecialEventHandling()..trigger = (EventTarget elem, data) {
      // jQuery: Fire native event if possible so blur/focus sequence is correct
      if (elem != document.activeElement) {
        (elem as Element).focus();
        return false;
      }
      return true;
      
    }..delegateType = 'focusin',
    'blur': new SpecialEventHandling()..trigger = (Element elem, data) {
      if (elem == document.activeElement) {
        (elem as Element).blur();
        return false;
      }
      return true;
      
    }..delegateType = 'focusout',
    'beforeunload': new SpecialEventHandling()..postDispatch = (DQueryEvent dqevent) {
      // jQuery: Support: Firefox 10+
      // TODO: problematic! as dqevent.originalEvent.returnValue is bool in Dart
      if (dqevent.result != null && dqevent.result is bool) // TODO: check design
        dqevent.originalEvent.returnValue = dqevent.result as bool;
    }
  });
  */
  
  // TODO: later
  /*
  static void simulate(String type, EventTarget elem, event, bool bubble) {
    // jQuery: Piggyback on a donor event to simulate a different one.
    //         Fake originalEvent to avoid donor's stopPropagation, but if the
    //         simulated event prevents default then we do the same on the donor.
    
    DQueryEvent e;
    // TODO
    /*
    var e = jQuery.extend(
        new jQuery.Event(),
        event,
        {
          type: type,
          isSimulated: true,
          originalEvent: {}
        }
    );
    */
    if (bubble)
      _EventUtil.trigger(e, null, elem);
    else
      _EventUtil.dispatch(elem, e);
    
    if (e.isDefaultPrevented)
      event.preventDefault();
    
  }
  */
  
}

/* due to the design of Dart, we can't easily extend List to attach an extra 
 * field on it, so we have to offer another layer to hold the List and the field.
 */
class HandleObjectContext {
  
  // TODO: just separate delegated handler objects
  
  List<HandleObject> delegates = new List<HandleObject>();
  
  List<HandleObject> handlers = new List<HandleObject>();
  
  int delegateCount = 0;
  
  static final HandleObjectContext EMPTY = new HandleObjectContext();
  
}

/*
class SpecialEventHandling {
  
  bool noBubble = false;
  Function setup, add, remove, teardown; // void f(Element elem, HandleObject handleObj) 
  Function trigger; // bool f(Element elem, data)
  Function _default; // bool f(Document document, data)
  String delegateType, bindType;
  DQueryEventListener postDispatch, handle;
  
  static final SpecialEventHandling EMPTY = new SpecialEventHandling();
  
}
*/

class _HandlerQueueEntry {
  
  final Element elem;
  final List<HandleObject> handlers;
  
  _HandlerQueueEntry(this.elem, this.handlers);
  
}

class HandleObject {
  
  HandleObject(this.guid, this.selector, this.type, this.origType, this.namespace,
      this.needsContext, this.handler);
  
  final int guid;
  
  final String selector, type, origType, namespace;
  
  final bool needsContext;
  
  final DQueryEventListener handler;
  
  var data;
  
}

/// 
typedef void DQueryEventListener(DQueryEvent event); 

/**
 * 
 */
class DQueryEvent {
  
  /** The time stamp at which the event occurs. If the event is constructed 
   * from a native DOM [Event], it uses the time stamp of that event. 
   */
  final int timeStamp;
  
  /// The original event, if any.
  final Event originalEvent;
  
  /** The type of event. If the event is constructed from a native DOM [Event], 
   * it uses the type of that event.
   */
  String get type => _type;
  String _type;
  
  /// Custom event data.
  var data;
  
  /// 
  //bool result;
  
  /// The delegate target of this event.
  Node get delegateTarget => _delegateTarget;
  Node _delegateTarget;
  
  /// 
  Node get currentTarget => _currentTarget;
  Node _currentTarget;
  
  String get namespace => _namespace;
  String _namespace;
  
  HandleObject _handleObj; // TODO: check usage
  final Event _simulatedEvent;
  
  int _isTrigger; // TODO: check usage
  
  /// 
  final Map attributes = new HashMap();
  
  DQueryEvent.from(Event event, [Map properties]) : 
  this._(event, null, event.type, event.target, event.timeStamp, properties);
  
  DQueryEvent(String type, Node target, [Map properties]) : 
  this._(null, new Event(type), type, target, _now(), properties);
  
  DQueryEvent._(this.originalEvent, this._simulatedEvent, this._type, 
      this._target, this.timeStamp, Map properties) {
    _mapMerge(attributes, properties);
    //attributes[expando] = true; // TODO: may not need this
  }
  
  /// The target of this event.
  Node get target => _target;
  Node _target;
  
  ///
  bool get isDefaultPrevented => _isDefaultPrevented;
  bool _isDefaultPrevented = false;
  
  ///
  bool get isPropagationStopped => _isPropagationStopped;
  bool _isPropagationStopped = false;
  
  ///
  bool get isImmediatePropagationStopped => _isImmediatePropagationStopped;
  bool _isImmediatePropagationStopped = false;
  
  /// Prevent default behavior of the event.
  void preventDefault() {
    _isDefaultPrevented = true;
    if (originalEvent != null)
      originalEvent.preventDefault();
  }
  
  /// Stop event propagation.
  void stopPropagation() {
    _isPropagationStopped = true;
    if (originalEvent != null)
      originalEvent.stopPropagation();
  }
  
  /// 
  void stopImmediatePropagation() {
    _isImmediatePropagationStopped = true;
    stopPropagation();
  }
  
}

// TODO: check 661-711 browser hack

abstract class EventMixin {
  
  DQuery get _this;
  
  /**
   * 
   */
  void on(String types, DQueryEventListener handler, {String selector, data}) {
    _on(types, handler, selector, data, false);
  }
  
  /**
   * 
   */
  void one(String types, DQueryEventListener handler, {String selector, data}) {
    _on(types, handler, selector, data, true);
  }
  
  /**
   * 
   */
  void _on(String types, DQueryEventListener handler, String selector, data, bool one) {
    if (handler == null)
      return;
    
    // TODO: handle guid for removal
    DQueryEventListener h = !one ? handler : (DQueryEvent dqevent) {
      // jQuery: Can use an empty set, since event contains the info
      _offEvent(dqevent);
      handler(dqevent);
    };
    
    _this._forEachNode((Node n) => _EventUtil.add(n, types, h, selector, data));
  }
  
  /**
   * 
   */
  void off(String types, DQueryEventListener handler, {String selector}) =>
    _this._forEachNode((Node n) => _EventUtil.remove(n, types, handler, selector));
  
  // utility refactored from off() to make type clearer
  static void _offEvent(DQueryEvent dqevent) {
    final HandleObject handleObj = dqevent._handleObj;
    final String type = handleObj.namespace != null ? 
        "${handleObj.origType}.${handleObj.namespace}" : handleObj.origType;
    new DQuery.elem(dqevent.delegateTarget).off(type, handleObj.handler, selector: handleObj.selector);
  }
  
  /**
   * 
   */
  void trigger(String type, [data]) =>
    _this._forEachNode((Node n) => _EventUtil.trigger(type, data, n));
  
  // TODO: [data] should be {data: data} for API consistency?
  
  /**
   * 
   */
  void triggerHandler(String type, [data]) {
    final Node n = _this._firstNode;
    if (n != null)
      _EventUtil.trigger(type, data, n, true);
  }
  
}