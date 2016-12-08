$banner=@"
  ___                     ___ _ _    _
 | _ \_____ __ _____ _ _ / __(_) |__| |__  ___ _ _
 |  _/ _ \ V  V / -_) '_| (_ | | '_ \ '_ \/ _ \ ' \
 |_| \___/\_/\_/\___|_|  \___|_|_.__/_.__/\___/_||_|
"@

Write-Host $banner
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
       [DllImport("user32.dll")]
       public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

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
$windowList = New-Object System.Collections.ArrayList
function RefreshWindowList(){
    param(
      [Parameter(Mandatory=$false)][IntPtr]$processScope
    )

    $windowList.Clear()
    $combobox.Items.Clear()
    foreach ($hWnd in ([APIFuncs]::GetChildWindows([APIFuncs]::GetDesktopWindow())))
    {
            #WindowName
            $windowName = (Get-WindowName($hwnd))
            if ($windowName -eq $null)
            {
                $windowName = "null"
            }

            #ProcessID
            $p = [IntPtr]::Zero
            [void][APIFuncs]::GetWindowThreadProcessId($hWnd, [ref]$p)
            if($processScope){
              if(!($processScope -eq $p))
              {
                continue
              }
            }
            #ProcessName
            $processName = (Get-Process -ID $p).ProcessName
            #WindowObject
            $windowObject = New-Object PSObject -Property @{Name=$windowName;Handle=$hWnd;processId=$p;processName=$processName}
            $windowObject | Add-Member ScriptMethod ToString {$this.Name} -force
            [void]$windowList.Add($windowObject)
    }
    $combobox.Items.AddRange($windowList)
}
function InitialiseWindowList(){
  RefreshWindowList
}

$windowHandle = 0

[Reflection.Assembly]::LoadWithPartialName( "System.Windows.Forms")
[Reflection.Assembly]::LoadWithPartialName( "System.Drawing.Point")
$form = New-Object Windows.Forms.Form

#Dropdown list of window handles
$combobox = New-Object System.Windows.Forms.ComboBox
$combobox.Location = New-Object System.Drawing.Point(25,0)
$combobox.Size = New-Object System.Drawing.Size(250,75)
InitialiseWindowList

$combobox_SelectedIndexChanged =
{
   $windowHandle = $combobox.selectedItem.Handle
   $windowTitle = $combobox.selectedItem.Name
   $windowPID = $combobox.selectedItem.processId
   $windowProcessName = $combobox.selectedItem.processName

   $windowLabel1.Text = "$windowTitle ($windowHandle)"
   $windowLabel2.Text = "$windowPID - $windowProcessName"
}

$combobox.add_SelectedIndexChanged($combobox_SelectedIndexChanged)
$form.Controls.Add($combobox)

#Label1
$windowLabel1 = New-Object System.Windows.Forms.Label
$windowLabel1.Text = "Window Name Goes Here"
$windowLabel1.Location = New-Object System.Drawing.Point(25,25)
$windowLabel1.Size = New-Object System.Drawing.Size(250,25)
$form.Controls.Add($windowLabel1)

#Label2
$windowLabel2 = New-Object System.Windows.Forms.Label
$windowLabel2.Text = "Window Name Goes Here"
$windowLabel2.Location = New-Object System.Drawing.Point(25,50)
$windowLabel2.Size = New-Object System.Drawing.Size(250,25)
$form.Controls.Add($windowLabel2)

#EnableWindow
$enableButton = New-Object System.Windows.Forms.Button
$enableButton.Text = "Enable"
$enableButton.Location = New-Object System.Drawing.Point(25,75)
$enableButton_click = {
    [APIFuncs]::EnableWindow($combobox.selectedItem.Handle, 1)
}
$enableButton.Add_Click($enableButton_click)
$form.Controls.Add($enableButton)

#DisableWindow
$disableButton = New-Object System.Windows.Forms.Button
$disableButton.Text = "Disable"
$disableButton.Location = New-Object System.Drawing.Point(25,100)
$disableButton_click = {
    [APIFuncs]::EnableWindow($combobox.selectedItem.Handle, 0)
}
$disableButton.Add_Click($disableButton_click)
$form.Controls.Add($disableButton)

#ShowWindow
$showButton = New-Object System.Windows.Forms.Button
$showButton.Text = "Show"
$showButton.Location = New-Object System.Drawing.Point(25,125)
$showButton_click = {
    [APIFuncs]::ShowWindow($combobox.selectedItem.Handle, 1)
}
$showButton.Add_Click($showButton_click)
$form.Controls.Add($showButton)

#HideWindow
$hideButton = New-Object System.Windows.Forms.Button
$hideButton.Text = "Hide"
$hideButton.Location = New-Object System.Drawing.Point(25,150)
$hideButton_click = {
    [APIFuncs]::ShowWindow($combobox.selectedItem.Handle, 0)
}
$hideButton.Add_Click($hideButton_click)
$form.Controls.Add($hideButton)

#RefreshList
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh List"
$refreshButton.Location = New-Object System.Drawing.Point(25,175)
$refreshButton_click = {
    RefreshWindowList
}
$refreshButton.Add_Click($refreshButton_click)
$form.Controls.Add($refreshButton)

#Refresh Rescope
#TODO: Consider whether this could probably be implemented more effectively by getting the parent of the selected window
$rescopeButton = New-Object System.Windows.Forms.Button
$rescopeButton.Text = "Rescope"
$rescopeButton.Location = New-Object System.Drawing.Point(25,200)
$rescopeButton_click = {
  RefreshWindowList($combobox.selectedItem.processId)
}
$rescopeButton.Add_Click($rescopeButton_click)
$form.Controls.Add($rescopeButton)

#ShowAll
$showAllButton = New-Object System.Windows.Forms.Button
$showAllButton.Text = "Show All"
$showAllButton.Location = New-Object System.Drawing.Point(25,225)
$showAllButton_click = {
  foreach ($hWnd in ([APIFuncs]::GetChildWindows([APIFuncs]::GetDesktopWindow())))
  {
    $p = [IntPtr]::Zero
    [void][APIFuncs]::GetWindowThreadProcessId($hWnd, [ref]$p)
    if ($p -eq $combobox.selectedItem.processId){
      [APIFuncs]::ShowWindow($hWnd, 1)
    }
  }
}
$showAllButton.Add_Click($showAllButton_click)
$form.Controls.Add($showAllButton)

$form.Text = "PowerGibbon"

$form.ShowDialog()
