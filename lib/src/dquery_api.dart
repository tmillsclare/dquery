//Copyright (C) 2013 Potix Corporation. All Rights Reserved.
part of dquery;

// TODO: fix selector/context getter
// TODO: check every incoming List<Element> of ElementQuery
// TODO: on() handler/selector argument position issue

/** A query object that wraps around DOM Elements, HtmlDocument, or Window, 
 * which offers API to register event listeners in a batch, or to retrieve
 * other query objects via selectors.
 */
abstract class DQuery<T> implements List<T> {
  
  // static methods //
  /** Return a sorted List of elements with duplicated items removed.
   */
  static List<Element> unique(List<Element> elements) => _unique(elements);
  
  // http://api.jquery.com/context/
  /** The DOM node context originally passed to DQuery; if none was passed 
   * then context will likely be the document.
   */
  get context;
  
  String get selector;
  
  /// Return the first matched element, or null if empty.
  T get firstIfAny;
  
  // moved from traversing to eliminate cyclic dependency
  // http://api.jquery.com/find/
  /** Retrieve an [ElementQuery] containing descendants of this element collection
   * which match the given [selector].
   */
  ElementQuery find(String selector); // TODO: need to fix for '> a', '+ a', '~ a'
  
  // skipped unless necessary
  //DQuery find(DQuery dquery); // requires filter()
  //DQuery find(Element element);
  
  // http://api.jquery.com/pushStack/
  /** Add a collection of DOM elements onto the DQuery stack.
   */
  ElementQuery pushStack(List<Element> elems);
  
  /** Pops out the top [DQuery] object in the stack and retrieve the previous one. 
   * If there is no previous [DQuery], an empty [DQuery] will be returned.
   * @see pushStack
   */
  DQuery end();
  
  // data //
  /** The interface to access custom element data.
   */
  Data get data;

  // event //
  /** Register a [handler] for events of given [types] on selected elements.
   * + If [selector] is provided, only the descendant elements matched by the
   * selector will trigger the event. If omitted or null, the event will always
   * be triggered.
   * + If [data] is provided, you can retrieve it in [event.data] in the handler.
   */
  void on(String types, DQueryEventListener handler, {String selector});
  
  /** Register a one-time [handler] for events of given [types]. Once called, 
   * the handler will be unregistered.
   * + If [selector] is provided, only the descendant elements matched by the
   * selector will trigger the event. If omitted or null, the event will always
   * be triggered.
   * + If [data] is provided, you can retrieve it in [event.data] in the handler.
   */
  void one(String types, DQueryEventListener handler, {String selector});

  /** Unregister a [handler] for events of given types.
   * // TODO
   */
  void off(String types, {String selector, DQueryEventListener handler});
  
  /** Trigger an event of given [type] on all matched elements, with given 
   * [data] if provided.
   */
  void trigger(String type, {data});
  
  /** Trigger the given [event] on all matched elements, with given [data] if
   * provided.
   */
  void triggerEvent(DQueryEvent event);
  
  /** Trigger an event of given [type] on the first (if any) matched element, 
   * with given [data] if provided. However, only the registered handlers will
   * be called, while the default action is omitted.
   */
  void triggerHandler(String type, {data});

  // traversing //
}

/** A query object of an [HtmlDocument].
 */
abstract class DocumentQuery extends DQuery<HtmlDocument> {
  factory DocumentQuery([HtmlDocument document]) => new _DocQuery(document);
}

/** A query object of a [Window].
 */
abstract class WindowQuery extends DQuery<Window> {
  factory WindowQuery([Window window]) => new _WinQuery(window);
}

/** A query object of a collection of [Element].
 */
abstract class ElementQuery extends DQuery<Element> {
  factory ElementQuery(List<Element> elements) => new _ElementQuery(elements);
  
  /** Retrieve the closest ancestor (including itself) of each element in this 
   * collection respectively who matches the given [selector].
   */
  ElementQuery closest(String selector);
  
  /** Retrieve the parents of each element in this collection.
   * + The redundant elements in the resulting collection will be removed.
   * + If [selector] is provided, parents who do not match the selector is 
   * filtered out.
   */
  ElementQuery parent([String selector]);
  
  /** Retrieve the union of childrens of each element in this collection.
   * + If [selector] is provided, children who do not match the selector is
   * filtered out.
   */
  ElementQuery children([String selector]);
  
  /** Show all the elements in this collection by changing their CSS display 
   * properties.
   */
  void show();
  
  /** Hide all the elements in this collection by setting their CSS disaply
   * properties value to [none].
   * 
   */
  void hide();
  
  /** Toggle the visibility of all the elements in this collection by altering
   * their CSS display properties.
   * 
   */
  void toggle([bool state]);
  
  /** Return true if any of the element contains the given [name] in its CSS
   * classes.
   */
  bool hasClass(String name);
  
  /** Add the CSS class of given [name] to all the elements in this collection.
   */
  void addClass(String name);
  
  /** Remove the CSS class of given [name] from all the elements in this collection.
   */
  void removeClass(String name);
  
  /** Toggle the CSS class of given [name] in all the elements in this collection.
   */
  void toggleClass(String name);
  
}
