if (("APIFuncs" -as [type]) -eq $null)
{
  #Maybe eventually turn this C# into powershell
  #Example EnumWindow code shamelessly pinched from http://www.pinvoke.net/default.aspx/user32.enumchildwindows
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    using System.Collections.Generic;
    using System.Text;
    public class APIFuncs
     {
       [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
       public static extern int GetWindowText(IntPtr hwnd,StringBuilder lpString, int cch);
       [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
       public static extern IntPtr GetForegroundWindow();
       [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
       public static extern Int32 GetWindowThreadProcessId(IntPtr hWnd,out Int32 lpdwProcessId);
       [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
       public static extern Int32 GetWindowTextLength(IntPtr hWnd);
       [DllImport("user32.dll", SetLastError = false)]
       public static extern IntPtr GetDesktopWindow();
       [DllImport("user32.dll")]
       public static extern bool EnableWindow(IntPtr hWnd, bool bEnable);
       [DllImport("user32.dll")]
       public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

       [DllImport("user32")]
       [return: MarshalAs(UnmanagedType.Bool)]
       public static extern bool EnumChildWindows(IntPtr window, EnumWindowProc callback, IntPtr i);

       public static List<IntPtr> GetChildWindows(IntPtr parent)
       {
          List<IntPtr> result = new List<IntPtr>();
          GCHandle listHandle = GCHandle.Alloc(result);
          try
          {
              EnumWindowProc childProc = new EnumWindowProc(EnumWindow);
              EnumChildWindows(parent, childProc,GCHandle.ToIntPtr(listHandle));
          }
          finally
          {
              if (listHandle.IsAllocated)
                  listHandle.Free();
          }
          return result;
      }
       private static bool EnumWindow(IntPtr handle, IntPtr pointer)
      {
          GCHandle gch = GCHandle.FromIntPtr(pointer);
          List<IntPtr> list = gch.Target as List<IntPtr>;
          if (list == null)
          {
              throw new InvalidCastException("GCHandle Target could not be cast as List<IntPtr>");
          }
          list.Add(handle);
          //  You can modify this to check to see if you want to cancel the operation, then return a null here
          return true;
      }
       public delegate bool EnumWindowProc(IntPtr hWnd, IntPtr parameter);
      }
"@
}

function Get-WindowName($hwnd) {
    $len = [APIFuncs]::GetWindowTextLength($hwnd)
    if($len -gt 0){
        $sb = New-Object text.stringbuilder -ArgumentList ($len + 1)
        $rtnlen = [APIFuncs]::GetWindowText($hwnd,$sb,$sb.Capacity)
        $sb.tostring()
    }
}

function RefreshWindowList(){
    $windowList = New-Object 'System.Collections.Generic.Dictionary[Int,String]'
    foreach ($hwnd in ([APIFuncs]::GetChildWindows([APIFuncs]::GetDesktopWindow())))
    {
            $windowName = (Get-WindowName($hwnd))
            if ($windowName -eq $null)
            {
                $windowName = "null"
            }
            $windowList.Add($hwnd, $windowName)
    }
    $dataSource = New-Object System.Windows.Forms.BindingSource -args $windowList, $null
    $combobox.DataSource =  $dataSource
    $combobox.DisplayMember = "Value"
    $combobox.ValueMember = "Key"
}

$windowHandle = 0

[Reflection.Assembly]::LoadWithPartialName( "System.Windows.Forms")
[Reflection.Assembly]::LoadWithPartialName( "System.Drawing.Point")
$form = New-Object Windows.Forms.Form

#Dropdown list of window handles
$combobox = New-Object System.Windows.Forms.ComboBox
$combobox.Location = New-Object System.Drawing.Point(25,0)
$combobox.Size = New-Object System.Drawing.Size(250,75)
RefreshWindowList

$combobox_SelectedIndexChanged =
{
   $windowHandle = $combobox.selectedItem.Key
   $windowTitle = $combobox.selectedItem.Value
   $windowLabel.Text = "$windowHandle ($windowTitle)"
}

$combobox.add_SelectedIndexChanged($combobox_SelectedIndexChanged)
$form.Controls.Add($combobox)

#WindowName
$windowLabel = New-Object System.Windows.Forms.Label
$windowLabel.Text = "Window Name Goes Here"
$windowLabel.Location = New-Object System.Drawing.Point(25,25)
$form.Controls.Add($windowLabel)

#EnableWindow
$enableButton = New-Object System.Windows.Forms.Button
$enableButton.Text = "Enable"
$enableButton.Location = New-Object System.Drawing.Point(25,50)
$enableButton_click = {
    [APIFuncs]::EnableWindow($combobox.selectedItem.Key, 1)
}
$enableButton.Add_Click($enableButton_click)
$form.Controls.Add($enableButton)

#DisableWindow
$disableButton = New-Object System.Windows.Forms.Button
$disableButton.Text = "Disable"
$disableButton.Location = New-Object System.Drawing.Point(25,75)
$disableButton_click = {
    [APIFuncs]::EnableWindow($combobox.selectedItem.Key, 0)
}
$disableButton.Add_Click($disableButton_click)
$form.Controls.Add($disableButton)

#ShowWindow
$showButton = New-Object System.Windows.Forms.Button
$showButton.Text = "Show"
$showButton.Location = New-Object System.Drawing.Point(25,100)
$showButton_click = {
    [APIFuncs]::ShowWindow($combobox.selectedItem.Key, 1)
}
$showButton.Add_Click($showButton_click)
$form.Controls.Add($showButton)

#HideWindow
$hideButton = New-Object System.Windows.Forms.Button
$hideButton.Text = "Hide"
$hideButton.Location = New-Object System.Drawing.Point(25,125)
$hideButton_click = {
    [APIFuncs]::ShowWindow($combobox.selectedItem.Key, 0)
}
$hideButton.Add_Click($hideButton_click)
$form.Controls.Add($hideButton)

#RefreshList
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh List"
$refreshButton.Location = New-Object System.Drawing.Point(25,150)
$refreshButton_click = {
    RefreshWindowList
}
$refreshButton.Add_Click($refreshButton_click)
$form.Controls.Add($refreshButton)

$form.Text = "PowerGibbon"

$form.ShowDialog()
