// See https://observablehq.com/framework/config for documentation.
export default {
  // The app’s title; used in the sidebar and webpage titles.
  title: "Ukraine Municipal Budget Analysis",

  // The pages and sections in the sidebar.
  pages: [
    {name: "Home", path: "/"},
    {name: "Budget Dashboard", path: "/budget-dashboard"},
    {name: "Capital Adjustments", path: "/adjustments"}
  ],

  // Content to add to the head of the page, e.g. for a favicon:
  head: '<link rel="icon" href="observable.png" type="image/png" sizes="32x32">',

  // The path to the source root.
  root: "src",

  // Theme and appearance
  theme: "light",
  sidebar: true,
  toc: true,
  pager: true,
  search: true,
  
  // Footer
  footer: "Built with Observable Framework. Data from Open Budget Ukraine."
};
